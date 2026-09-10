# frozen_string_literal: true

require "test_helper"

class ShopifyAuthenticatorTest < ActiveSupport::TestCase
  test "strict signature parsing rejects ambiguous headers and malformed inputs" do
    source = Webhooks::ShopifySource.new(shop_id: 7, shop_domain: "synthetic.myshopify.com", secret: "test-secret")
    body = "exact\x00bytes".b
    signature = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", source.secret, body))
    verifier = Webhooks::ShopifyAuthenticator.new
    assert verifier.call(raw_body: body, headers: { "x-shopify-hmac-sha256" => signature }, source_configuration: source)
    [ {}, { "X-Shopify-Hmac-Sha256" => nil }, { "X-Shopify-Hmac-Sha256" => signature + "\n" },
      { "X-Shopify-Hmac-Sha256" => signature, "x-shopify-hmac-sha256" => signature } ].each do |headers|
      refute verifier.call(raw_body: body, headers: headers, source_configuration: source)
    end
    refute verifier.call(raw_body: nil, headers: {}, source_configuration: source)
    refute verifier.call(raw_body: body, headers: [], source_configuration: source)
    refute verifier.call(raw_body: body, headers: {}, source_configuration: nil)
  end

  test "source configuration is explicit immutable and redacted and production fails closed" do
    entry = { "route_token" => "a" * 64, "shop_id" => 7, "shop_domain" => "synthetic.myshopify.com", "secret" => "synthetic-secret".dup }
    registry = Webhooks::ShopifySources.new(entries: [ entry ])
    entry["secret"].replace("changed")
    assert_equal "synthetic-secret", registry.find(route_token: "a" * 64).secret
    assert_nil registry.find(route_token: nil)
    assert_nil registry.find(route_token: "a" * 65)
    refute_includes registry.inspect, "synthetic-secret"
    refute_includes registry.to_json, "a" * 64
    assert_raises(Webhooks::ShopifySources::ConfigurationError) { Webhooks::ShopifySources.from_environment(environment: "production", env: {}) }
    [ nil, [], [ entry, entry ], [ entry.merge("route_token" => "fixture") ], [ entry.merge("shop_id" => 0) ], [ entry.merge("extra" => true) ] ].each do |entries|
      error = assert_raises(Webhooks::ShopifySources::ConfigurationError) { Webhooks::ShopifySources.new(entries: entries) }
      assert_nil error.cause
      refute_includes error.message, "changed"
    end
  end
end
