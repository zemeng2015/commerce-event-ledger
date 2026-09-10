# frozen_string_literal: true

require "test_helper"

class OrderProcessingTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  include ActiveSupport::Testing::TimeHelpers

  setup do
    clean_database
    @sequence = 0
    @body = File.binread(Rails.root.join("fixtures/shopify/orders_create.json"))
    @headers = JSON.parse(File.read(Rails.root.join("fixtures/shopify/orders_create_headers.json")))
    @secret = "ledger-fixture-secret-do-not-use-outside-local"
  end

  teardown do
    travel_back
    clean_database
  end

  test "duplicate job execution commits one effect and projection transition" do
    event = persisted_event
    10.times { CommerceEventLedger::ProcessEventJob.perform_now(7, event.event_id) }
    assert_equal 1, count("processed_effects")
    assert_equal 1, count("order_projections")
    assert_equal 1, row("order_projections").fetch("transition_count")
    assert_equal "processed", row("received_events").fetch("status")
    assert_equal "succeeded", row("processing_attempts").fetch("status")
    assert_equal 1, count("processing_attempts")
  end

  test "competing effect executors observe one committed database effect" do
    event = persisted_event
    ready = Queue.new
    start = Queue.new
    workers = 10.times.map do
      Thread.new do
        ready << true
        start.pop
        Orders::EffectExecutor.new.call(event: event)
      end
    end
    10.times { ready.pop }
    10.times { start << true }
    results = workers.map(&:value)
    assert_equal 1, results.count { |result| !result.duplicate }
    assert_equal 1, results.map(&:effect_id).uniq.size
    assert_equal 1, count("processed_effects")
    assert_equal 1, row("order_projections").fetch("transition_count")
  end

  test "effect insert failure rolls back the projection in the same primary transaction" do
    event = persisted_event
    connection { |db| db.execute("ALTER TABLE processed_effects ADD CONSTRAINT reject_test_effect CHECK (outcome = 'fault-injection')") }
    installed = true
    error = assert_raises(Orders::EffectExecutor::ExecutionError) { Orders::EffectExecutor.new.call(event: event) }
    assert_nil error.cause
    refute_includes error.message, "reject_test_effect"
    assert_equal 0, count("processed_effects")
    assert_equal 0, count("order_projections")
    assert_equal 1, count("received_events")
  ensure
    connection { |db| db.execute("ALTER TABLE processed_effects DROP CHECK reject_test_effect") } if installed
  end

  test "an enclosing transaction cannot absorb the effect commit" do
    event = persisted_event
    connection do |db|
      db.transaction do
        assert_raises(Orders::EffectExecutor::ExecutionError) { Orders::EffectExecutor.new.call(event: event) }
      end
    end
    assert_equal 0, count("processed_effects")
    assert_equal 0, count("order_projections")
  end

  test "older and equal nanosecond versions record stale effects without regressing the projection" do
    newest = persisted_event(updated_at: "2026-09-04T12:00:00.123456789Z")
    older = persisted_event(updated_at: "2026-09-04T12:00:00.123456788Z")
    equal = persisted_event(updated_at: "2026-09-04T12:00:00.123456789Z")
    executor = Orders::EffectExecutor.new
    assert_equal :applied, executor.call(event: newest).outcome
    assert_equal :stale, executor.call(event: older).outcome
    assert_equal :stale, executor.call(event: equal).outcome
    duplicate = executor.call(event: older)
    assert duplicate.duplicate
    assert_equal :stale, duplicate.outcome
    assert_equal 3, count("processed_effects")
    assert_equal 1, row("order_projections").fetch("transition_count")
    assert_equal newest.event_id, row("order_projections").fetch("last_event_id")
    assert_equal "2026-09-04T12:00:00.123456789Z", row("order_projections").fetch("source_occurred_at")
  end

  test "tenant composite foreign keys reject a fabricated cross-tenant event association" do
    first = persisted_event
    second = persisted_event(shop_id: 8)
    fabricated = EventLedger::PersistedEvent.new(event_id: first.event_id, envelope: second.envelope,
      received_at: first.received_at, handler_name: first.handler_name, handler_version: first.handler_version)
    assert_raises(Orders::EffectExecutor::ExecutionError) { Orders::EffectExecutor.new.call(event: fabricated) }
    assert_equal 0, count("processed_effects")
    assert_equal 0, count("order_projections")
  end

  test "claim is tenant scoped and expired owners cannot acknowledge a newer attempt" do
    event = persisted_event
    store = EventLedger::ProcessingStore.new(shop_id: 7)
    assert_nil EventLedger::ProcessingStore.new(shop_id: 8).claim(event_id: event.event_id)
    first = store.claim(event_id: event.event_id)
    assert_nil store.claim(event_id: event.event_id)
    travel 301.seconds
    second = store.claim(event_id: event.event_id)
    assert_equal 2, second.attempt_number
    refute_equal first.token, second.token
    refute store.finish(claim: first)
    refute store.fail(claim: first)
    assert_equal "processing", row("received_events").fetch("status")
    assert store.finish(claim: second)
    assert_equal "processed", row("received_events").fetch("status")
    assert_nil store.claim(event_id: event.event_id)
  end

  test "an unavailable assigned handler retries boundedly and remains dead letter after exhaustion" do
    event = persisted_event(handler_version: "unavailable-version")
    5.times do |index|
      CommerceEventLedger::ProcessEventJob.perform_now(7, event.event_id)
      assert_equal index + 1, row("received_events").fetch("attempt_count")
      travel 31.seconds
    end
    assert_equal "dead_letter", row("received_events").fetch("status")
    assert_equal "handler_failed", row("received_events").fetch("last_error_code")
    assert_equal 0, count("processed_effects")
    refute_includes EventLedger::ProcessingStore.eligible_event_ids, [ 7, event.event_id ]
    CommerceEventLedger::ProcessEventJob.perform_now(7, event.event_id)
    assert_equal 5, count("processing_attempts")
  end

  test "queue insertion happens after receipt and failure leaves recoverable pending state" do
    assert_instance_of ActiveJob::QueueAdapters::SolidQueueAdapter, CommerceEventLedger::ProcessEventJob.queue_adapter
    connection { |db| db.execute("ALTER TABLE solid_queue_jobs ADD CONSTRAINT reject_test_enqueue CHECK (queue_name = 'fault-injection')") }
    installed = true
    signature = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", @secret, @body))
    env = Rack::MockRequest.env_for("/webhooks/shopify/fixture", method: "POST", input: @body)
    @headers.each { |key, value| env["HTTP_#{key.upcase.tr('-', '_')}"] = value }
    env["HTTP_X_SHOPIFY_HMAC_SHA256"] = signature
    assert_equal 202, Rails.application.call(env).first
    assert_equal 0, count("solid_queue_jobs")
    assert_equal "pending", row("received_events").fetch("status")
    assert_equal [ [ 7, row("received_events").fetch("id") ] ], EventLedger::ProcessingStore.eligible_event_ids
    connection { |db| db.execute("ALTER TABLE solid_queue_jobs DROP CHECK reject_test_enqueue") }
    installed = false
    CommerceEventLedger::RecoverEventsJob.perform_now
    assert_equal 1, count("solid_queue_jobs")
    refute_includes row("solid_queue_jobs").fetch("arguments"), @body
  ensure
    connection { |db| db.execute("ALTER TABLE solid_queue_jobs DROP CHECK reject_test_enqueue") } if installed
  end

  test "recovery after an unacknowledged committed effect retains a single domain transition" do
    event = persisted_event
    store = EventLedger::ProcessingStore.new(shop_id: 7)
    first = store.claim(event_id: event.event_id)
    effect = Orders::EffectExecutor.new.call(event: first.event)
    travel 301.seconds
    CommerceEventLedger::ProcessEventJob.perform_now(7, event.event_id)
    assert_equal "processed", row("received_events").fetch("status")
    assert_equal effect.effect_id, row("processed_effects").fetch("id")
    assert_equal 1, row("order_projections").fetch("transition_count")
    assert_equal 2, count("processing_attempts")
    refute store.finish(claim: first)
  end

  private

  def persisted_event(shop_id: 7, updated_at: "2026-09-04T12:00:00Z", handler_version: "v1")
    @sequence += 1
    headers = @headers.merge("X-Shopify-Event-Id" => "processing-test-#{@sequence}")
    domain = shop_id == 7 ? @headers.fetch("X-Shopify-Shop-Domain") : "second-synthetic-shop.myshopify.com"
    headers["X-Shopify-Shop-Domain"] = domain
    source = Webhooks::ShopifySource.new(shop_id: shop_id, shop_domain: domain, secret: @secret)
    body = JSON.generate(JSON.parse(@body).merge("updated_at" => updated_at))
    envelope = Webhooks::ShopifyOrderCreate.new.call(raw_body: body, headers: headers, source_configuration: source)
    receipt = EventLedger::ReceiptStore.new(shop_id: shop_id, shop_domain: domain)
      .receive(envelope: envelope, handler_name: "order_projection", handler_version: handler_version)
    EventLedger::PersistedEvent.new(event_id: receipt.event_id, envelope: envelope,
      received_at: Time.now.utc, handler_name: "order_projection", handler_version: handler_version)
  end

  def connection(&block)
    ActiveRecord::Base.connection_pool.with_connection(&block)
  end

  def count(table)
    connection { |db| db.select_value("SELECT COUNT(*) FROM #{db.quote_table_name(table)}") }
  end

  def row(table)
    connection { |db| db.select_one("SELECT * FROM #{db.quote_table_name(table)} ORDER BY id LIMIT 1") }
  end

  def clean_database
    connection do |db|
      raise "Unsafe test database" unless db.select_value("SELECT DATABASE()") == "commerce_event_ledger_test"
      %w[solid_queue_jobs processing_attempts processed_effects order_projections received_events shops].each do |table|
        db.execute("DELETE FROM #{db.quote_table_name(table)}")
      end
    end
  end
end
