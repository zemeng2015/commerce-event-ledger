# frozen_string_literal: true

require "test_helper"

class ShopifyOrderCreateTest < ActiveSupport::TestCase
  setup do
    @body = File.binread(Rails.root.join("fixtures/shopify/orders_create.json"))
    @headers = JSON.parse(File.read(Rails.root.join("fixtures/shopify/orders_create_headers.json")))
    @source = Webhooks::ShopifySource.new(shop_id: 7,
      shop_domain: @headers.fetch("X-Shopify-Shop-Domain"), secret: "synthetic-secret-marker")
    @normalizer = Webhooks::ShopifyOrderCreate.new
  end

  test "normalization retains precise resource identity and drops sensitive fields" do
    payload = JSON.parse(@body).merge("email" => "synthetic-secret-marker", "customer" => { "name" => "synthetic-secret-marker" })
    body = JSON.generate(payload)
    event = normalize(body: body)
    assert_equal "orders/create:#{@headers.fetch('X-Shopify-Event-Id')}", event.external_event_id
    assert_equal "900000000000001", event.subject_id
    assert_equal 7, event.shop_id
    assert_equal %w[created_at order_id state updated_at], event.payload.keys.sort
    assert_equal "created", event.payload.fetch("state")
    assert_equal Time.utc(2026, 9, 4, 12), event.occurred_at
    assert_nil event.source_version
    assert_equal Digest::SHA256.hexdigest(body), event.payload_sha256
    assert event.payload.frozen?
    refute_includes event.payload.to_json, "synthetic-secret-marker"
    refute_includes event.to_json, "900000000000001"
  end

  test "delivery identifiers do not replace or change the canonical identity" do
    first = normalize(headers: @headers.merge("X-Shopify-Webhook-Id" => SecureRandom.uuid))
    second = normalize(headers: @headers.transform_keys(&:downcase).merge("x-shopify-webhook-id" => SecureRandom.uuid))
    assert_equal first.external_event_id, second.external_event_id
    assert_equal first.external_event_id, normalize(headers: @headers.merge("X-Shopify-Event-Id" => @headers.fetch("X-Shopify-Event-Id").upcase)).external_event_id
    assert_invalid(headers: @headers.except("X-Shopify-Event-Id").merge("X-Shopify-Webhook-Id" => SecureRandom.uuid))
  end

  test "required headers reject ambiguity topic version domain and malformed identity" do
    @headers.each_key { |key| assert_invalid(headers: @headers.except(key)) }
    { "X-Shopify-Topic" => "orders/updated", "X-Shopify-API-Version" => "2026-04",
      "X-Shopify-Shop-Domain" => "another.myshopify.com", "X-Shopify-Event-Id" => "synthetic-secret-marker" }.each do |key, value|
      assert_invalid(headers: @headers.merge(key => value))
    end
    assert_invalid(headers: @headers.merge("x-shopify-topic" => "orders/create"))
    assert_invalid(headers: @headers.merge("X-Shopify-Event-Id" => nil))
    assert_invalid(headers: @headers.merge(1 => "bad"))
    assert_invalid(headers: nil)
  end

  test "strict JSON and bounded UTF8 reject malformed and ambiguous documents" do
    [ "{synthetic-secret-marker", "[]", "null", "{\"id\":1,\"id\":2}",
      '{"nested":{"secret":1,"secret":2}}', "{\"id\":NaN}", "\xFF".b,
      " " * 1_048_577, "[" * 65 + "0" + "]" * 65 ].each { |body| assert_invalid(body: body) }
    assert_invalid(body: nil)
    assert_invalid(source: Object.new)
  end

  test "ids must be positive integers and required timestamps must be present" do
    [ nil, 0, -1, 1.0, "900000000000001", true ].each do |id|
      assert_invalid(body: JSON.generate(JSON.parse(@body).merge("id" => id)))
    end
    %w[id created_at updated_at].each do |field|
      assert_invalid(body: JSON.generate(JSON.parse(@body).except(field)))
    end
  end

  test "timestamps preserve offsets and nanoseconds without a delivery-time version" do
    payload = JSON.parse(@body).merge("created_at" => "2026-09-04T08:00:00-04:00", "updated_at" => "2026-09-04T12:00:01.123456789Z")
    event = normalize(body: JSON.generate(payload), headers: @headers.merge("X-Shopify-Triggered-At" => "2099-01-01T00:00:00Z"))
    assert_equal "2026-09-04T12:00:00.000000000Z", event.payload.fetch("created_at")
    assert_equal 123456789, event.occurred_at.nsec
    assert_nil event.source_version
  end

  test "invalid calendar times missing offsets and reversed resource times are rejected" do
    [ nil, 0, "2026-02-30T12:00:00Z", "2026-09-04T12:00:00", "2026-09-04T24:00:00Z",
      "2026-09-04T12:00:00.1234567890Z", "2026-09-03T12:00:00Z", "0000-01-01T00:00:00Z" ].each do |value|
      assert_invalid(body: JSON.generate(JSON.parse(@body).merge("updated_at" => value)))
    end
  end

  test "source configuration is immutable explicit and redacted" do
    domain = +"fixture.myshopify.com"
    secret = +"synthetic-secret-marker"
    source = Webhooks::ShopifySource.new(shop_id: 7, shop_domain: domain, secret: secret)
    domain.replace("changed")
    secret.replace("changed")
    assert_equal "fixture.myshopify.com", source.shop_domain
    assert_equal "synthetic-secret-marker", source.secret
    assert_equal "shopify", source.source
    assert source.frozen?
    assert source.secret.frozen?
    [ source, @normalizer ].each do |value|
      refute_includes value.inspect, "synthetic-secret-marker"
      assert_equal true, value.as_json.fetch("redacted")
    end
    [ "https://fixture.myshopify.com", "UPPER.myshopify.com", "-bad.myshopify.com", "a" * 64 + ".myshopify.com" ].each do |invalid|
      assert_raises(ArgumentError) { Webhooks::ShopifySource.new(shop_id: 7, shop_domain: invalid, secret: "x") }
    end
    assert_raises(ArgumentError) { Webhooks::ShopifySource.new(shop_id: 0, shop_domain: @source.shop_domain, secret: "x") }
    assert_raises(ArgumentError) { Webhooks::ShopifySource.new(shop_id: 7, shop_domain: @source.shop_domain, secret: "") }
  end

  private

  def normalize(body: @body, headers: @headers, source: @source)
    @normalizer.call(raw_body: body, headers: headers, source_configuration: source)
  end

  def assert_invalid(**arguments)
    error = assert_raises(Webhooks::ShopifyOrderCreate::NormalizationError) { normalize(**arguments) }
    assert_nil error.cause
    refute_includes error.full_message, "synthetic-secret-marker"
  end
end
