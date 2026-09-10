# frozen_string_literal: true

module Webhooks
  # Constructed by server configuration, never from webhook headers alone.
  class ShopifySource
    attr_reader :shop_id, :shop_domain, :secret

    def initialize(shop_id:, shop_domain:, secret:)
      unless shop_id.is_a?(Integer) && shop_id.positive? &&
        shop_domain.is_a?(String) && shop_domain.ascii_only? &&
        shop_domain.match?(/\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.myshopify\.com\z/) &&
        secret.is_a?(String) && !secret.empty?
        raise ArgumentError, "Invalid Shopify source configuration"
      end
      @shop_id = shop_id
      @shop_domain = shop_domain.dup.freeze
      @secret = secret.dup.freeze
      freeze
    end

    def source
      "shopify"
    end

    def inspect
      "#<Webhooks::ShopifySource [REDACTED]>"
    end
    alias_method :to_s, :inspect

    def as_json(_options = nil)
      { "type" => self.class.name, "redacted" => true }
    end
  end
end
