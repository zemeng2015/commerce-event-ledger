# frozen_string_literal: true

require "json"

module Webhooks
  class HttpReceiver
    MAX_BODY_BYTES = 1_048_576

    def initialize(sources:, handler_name:, handler_version:)
      @sources = sources
      @handler_name = handler_name
      @handler_version = handler_version
    end

    def call(env)
      return response(405, "method_not_allowed", "allow" => "POST") unless env["REQUEST_METHOD"] == "POST"
      token = env.fetch("PATH_INFO", "")[%r{\A/webhooks/shopify/([0-9a-f]{64}|fixture)\z}, 1]
      source = @sources.find(route_token: token)
      return response(401, "unauthorized") unless source
      headers = env.each_with_object({}) do |(key, value), result|
        result[key.delete_prefix("HTTP_").tr("_", "-")] = value if key.start_with?("HTTP_X_SHOPIFY_")
      end
      # HMAC covers the body, not these headers. The capability selects the tenant.
      return response(401, "unauthorized") unless headers["X-SHOPIFY-SHOP-DOMAIN"] == source.shop_domain
      length = env["CONTENT_LENGTH"]
      return response(413, "body_too_large") if length && length.to_i > MAX_BODY_BYTES
      body = env.fetch("rack.input").read(MAX_BODY_BYTES + 1)
      return response(413, "body_too_large") if body.bytesize > MAX_BODY_BYTES
      unless ShopifyAuthenticator.new.call(raw_body: body, headers: headers, source_configuration: source)
        return response(401, "unauthorized")
      end
      envelope = ShopifyOrderCreate.new.call(raw_body: body, headers: headers, source_configuration: source)
      receipt = EventLedger::ReceiptStore.new(shop_id: source.shop_id, shop_domain: source.shop_domain)
        .receive(envelope: envelope, handler_name: @handler_name, handler_version: @handler_version)
      [202, { "content-type" => "application/json", "cache-control" => "no-store" },
        [JSON.generate(event_id: receipt.event_id, duplicate: receipt.duplicate, status: "pending")]]
    rescue ShopifyOrderCreate::NormalizationError
      response(400, "invalid_webhook")
    rescue EventLedger::ReceiptStore::IdentityConflict
      response(409, "identity_conflict")
    rescue StandardError
      response(503, "unavailable")
    end

    def inspect
      "#<Webhooks::HttpReceiver [REDACTED]>"
    end
    alias_method :to_s, :inspect

    def as_json(_options = nil)
      { "type" => self.class.name, "redacted" => true }
    end

    private

    def response(status, error, headers = {})
      [status, { "content-type" => "application/json", "cache-control" => "no-store" }.merge(headers),
        [JSON.generate(error: error)]]
    end
  end
end
