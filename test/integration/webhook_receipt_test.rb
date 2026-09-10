# frozen_string_literal: true

require "test_helper"
require "base64"
require "openssl"
require "stringio"

class WebhookReceiptTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    clear_receipts
    @body = File.binread(Rails.root.join("fixtures/shopify/orders_create.json"))
    @headers = JSON.parse(File.read(Rails.root.join("fixtures/shopify/orders_create_headers.json")))
    @secret = "ledger-fixture-secret-do-not-use-outside-local"
    @old_sources = ENV.delete("LEDGER_SHOPIFY_SOURCES")
    @old_secret = ENV.delete("LEDGER_FIXTURE_SECRET")
  end

  teardown do
    @old_sources ? ENV["LEDGER_SHOPIFY_SOURCES"] = @old_sources : ENV.delete("LEDGER_SHOPIFY_SOURCES")
    @old_secret ? ENV["LEDGER_FIXTURE_SECRET"] = @old_secret : ENV.delete("LEDGER_FIXTURE_SECRET")
    clear_receipts
  end

  test "accepted receipt is visible from another connection and contains only normalized data" do
    status, _, chunks = request
    assert_equal 202, status
    result = JSON.parse(chunks.join)
    row = Thread.new { connection { |db| db.select_one("SELECT * FROM received_events") } }.value
    assert_equal result.fetch("event_id"), row.fetch("id")
    assert_equal "pending", row.fetch("status")
    assert_equal "2026-09-04T12:00:00.000000000Z", row.fetch("source_occurred_at")
    assert_equal Digest::SHA256.hexdigest(@body), row.fetch("payload_sha256")
    refute_includes row.fetch("normalized_payload"), "note"
    refute result.fetch("duplicate")
  end

  test "ten sequential and ten concurrent duplicates each leave one canonical event" do
    10.times { assert_equal 202, request.first }
    assert_equal 1, count
    assert_equal 10, rows.first.fetch("deliveries_count")
    clear_receipts
    ready = Queue.new
    start = Queue.new
    workers = 10.times.map do
      Thread.new do
        ready << true
        start.pop
        request.first
      end
    end
    10.times { ready.pop }
    10.times { start << true }
    assert_equal [202] * 10, workers.map(&:value)
    assert_equal 1, count
    assert_equal 10, rows.first.fetch("deliveries_count")
  end

  test "invalid signatures and altered exact bytes do not register a tenant or event" do
    [nil, "", "bad", Base64.strict_encode64("x" * 32), Base64.strict_encode64("x" * 31)].each do |signature|
      assert_equal 401, request(signature: signature).first
    end
    assert_equal 401, request(body: @body + " ", signature: sign(@body)).first
    assert_equal 0, count
    assert_equal 0, connection { |db| db.select_value("SELECT COUNT(*) FROM shops") }
  end

  test "tenant capability and expected domain bind requests even with a shared application secret" do
    first_token = "a" * 64
    second_token = "b" * 64
    second_domain = "second-synthetic-shop.myshopify.com"
    ENV["LEDGER_SHOPIFY_SOURCES"] = JSON.generate([
      { route_token: first_token, shop_id: 7, shop_domain: @headers.fetch("X-Shopify-Shop-Domain"), secret: @secret },
      { route_token: second_token, shop_id: 8, shop_domain: second_domain, secret: @secret }
    ])
    assert_equal 401, request.first
    assert_equal 401, request(path: "/webhooks/shopify/#{first_token}", domain: second_domain).first
    assert_equal 401, request(path: "/webhooks/shopify/#{'c' * 64}").first
    assert_equal 202, request(path: "/webhooks/shopify/#{first_token}").first
    assert_equal 202, request(path: "/webhooks/shopify/#{second_token}", domain: second_domain).first
    assert_equal [7, 8], rows.map { |row| row.fetch("shop_id") }.sort
  end

  test "conflicting exact payload cannot replace canonical content or increment accepted duplicates" do
    assert_equal 202, request.first
    original = rows.first
    assert_equal 409, request(body: @body + " ").first
    assert_equal original, rows.first
  end

  test "binary collation preserves case-sensitive external identifiers" do
    assert_equal 202, request(event_id: "Event-A").first
    assert_equal 202, request(event_id: "event-a").first
    assert_equal 2, count
    assert_equal "utf8mb4_0900_bin", connection { |db| db.select_value("SELECT TABLE_COLLATION FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'received_events'") }
  end

  test "duplicate receipt retains original handler assignment and source nanoseconds" do
    source = Webhooks::ShopifySource.new(shop_id: 7, shop_domain: @headers.fetch("X-Shopify-Shop-Domain"), secret: @secret)
    body = @body.gsub("12:00:00Z", "12:00:00.123456789Z")
    envelope = Webhooks::ShopifyOrderCreate.new.call(raw_body: body, headers: @headers, source_configuration: source)
    store = EventLedger::ReceiptStore.new(shop_id: 7, shop_domain: source.shop_domain)
    receipt = store.receive(envelope: envelope, handler_name: "order_projection", handler_version: "v1")
    duplicate = store.receive(envelope: envelope, handler_name: "order_projection", handler_version: "v2")
    assert_equal receipt.event_id, duplicate.event_id
    assert duplicate.duplicate
    assert_equal "v1", rows.first.fetch("handler_version")
    assert_equal "2026-09-04T12:00:00.123456789Z", rows.first.fetch("source_occurred_at")
  end

  test "outer transaction cannot produce an acknowledgment before commit" do
    connection do |db|
      db.transaction { assert_equal 503, request.first }
    end
    assert_equal 0, count
  end

  test "database failure rolls back tenant registration and returns sanitized unavailable" do
    # A real MySQL trigger fails the event insert after the shop insert.
    connection { |db| db.execute("CREATE TRIGGER reject_test_receipt BEFORE INSERT ON received_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'synthetic-database-secret'") }
    status, _, chunks = request
    assert_equal 503, status
    refute_includes chunks.join, "synthetic-database-secret"
    assert_equal 0, count
    assert_equal 0, connection { |db| db.select_value("SELECT COUNT(*) FROM shops") }
  ensure
    connection { |db| db.execute("DROP TRIGGER IF EXISTS reject_test_receipt") }
  end

  test "malformed supported-route requests have bounded sanitized responses" do
    assert_equal 400, request(body: "{bad-json").first
    assert_equal 400, request(topic: "orders/updated").first
    assert_equal 413, request(body: "x" * 1_048_577).first
    assert_equal 405, request(method: "GET").first
    ENV["LEDGER_SHOPIFY_SOURCES"] = "not-json-secret-marker"
    status, _, body = request
    assert_equal 503, status
    refute_includes body.join, "secret-marker"
    assert_equal 0, count
  end

  test "duplicate JSON keys cannot leak input through parser warnings" do
    output, errors = capture_io do
      assert_equal 400, request(body: '{"synthetic-sensitive-key":1,"synthetic-sensitive-key":2}').first
    end
    assert_empty output
    assert_empty errors
  end

  test "the Rails request logger never sees capability URLs or raw webhook bodies" do
    output = StringIO.new
    previous_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    assert_equal 401, request(path: "/webhooks/shopify/#{'d' * 64}", body: "synthetic-raw-body-secret").first
    refute_includes output.string, "d" * 64
    refute_includes output.string, "synthetic-raw-body-secret"
  ensure
    Rails.logger = previous_logger
  end

  private

  def request(body: @body, signature: sign(body), path: "/webhooks/shopify/fixture", method: "POST",
    domain: @headers.fetch("X-Shopify-Shop-Domain"), event_id: @headers.fetch("X-Shopify-Event-Id"), topic: "orders/create")
    env = Rack::MockRequest.env_for(path, method: method, input: body)
    @headers.each { |key, value| env["HTTP_#{key.upcase.tr('-', '_')}"] = value }
    env["HTTP_X_SHOPIFY_SHOP_DOMAIN"] = domain
    env["HTTP_X_SHOPIFY_EVENT_ID"] = event_id
    env["HTTP_X_SHOPIFY_TOPIC"] = topic
    env["HTTP_X_SHOPIFY_HMAC_SHA256"] = signature if signature
    Rails.application.call(env)
  end

  def sign(body)
    Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", @secret, body))
  end

  def connection(&block)
    ActiveRecord::Base.connection_pool.with_connection(&block)
  end

  def rows
    connection { |db| db.select_all("SELECT * FROM received_events ORDER BY id").to_a }
  end

  def count
    connection { |db| db.select_value("SELECT COUNT(*) FROM received_events") }
  end

  def clear_receipts
    connection do |db|
      raise "Unsafe test database" unless db.select_value("SELECT DATABASE()") == "commerce_event_ledger_test"
      db.execute("DELETE FROM received_events")
      db.execute("DELETE FROM shops")
    end
  end
end
