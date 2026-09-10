# frozen_string_literal: true

require "json"
require "digest/sha2"

module Webhooks
  # Route capabilities are server-owned credentials, independent of signed body bytes.
  class ShopifySources
    class ConfigurationError < StandardError; end

    def initialize(entries:, allow_fixture: false)
      raise ArgumentError unless entries.is_a?(Array) && entries.length.between?(1, 100)
      shops = []
      domains = []
      @sources = entries.each_with_object({}) do |entry, sources|
        raise ArgumentError unless entry.is_a?(Hash) && entry.keys.sort == %w[route_token secret shop_domain shop_id]
        token = entry.fetch("route_token")
        raise ArgumentError unless token.is_a?(String) &&
          (token.match?(/\A[0-9a-f]{64}\z/) || (allow_fixture && token == "fixture"))
        key = Digest::SHA256.hexdigest(token)
        source = ShopifySource.new(shop_id: entry.fetch("shop_id"),
          shop_domain: entry.fetch("shop_domain"), secret: entry.fetch("secret"))
        raise ArgumentError if sources.key?(key) || shops.include?(source.shop_id) || domains.include?(source.shop_domain)
        sources[key] = source
        shops << source.shop_id
        domains << source.shop_domain
      end.freeze
      freeze
    rescue StandardError
      raise ConfigurationError, "Invalid webhook source configuration", cause: nil
    end

    def self.from_environment(environment:, env: ENV)
      fixture = %w[development test].include?(environment)
      entries = if env.key?("LEDGER_SHOPIFY_SOURCES")
        JSON.parse(env.fetch("LEDGER_SHOPIFY_SOURCES"), object_class: UniqueJsonObject,
          max_nesting: 8, create_additions: false, allow_duplicate_key: true)
      elsif fixture
        [ { "route_token" => "fixture", "shop_id" => 7,
          "shop_domain" => "commerce-event-ledger-fixture.myshopify.com",
          "secret" => env.fetch("LEDGER_FIXTURE_SECRET", "ledger-fixture-secret-do-not-use-outside-local") } ]
      else
        raise ConfigurationError
      end
      new(entries: entries, allow_fixture: fixture)
    rescue StandardError
      raise ConfigurationError, "Invalid webhook source configuration", cause: nil
    end

    def find(route_token:)
      return nil unless route_token.is_a?(String) && route_token.bytesize <= 64
      @sources[Digest::SHA256.hexdigest(route_token)]
    end

    def inspect
      "#<Webhooks::ShopifySources [REDACTED]>"
    end
    alias_method :to_s, :inspect

    def as_json(_options = nil)
      { "type" => self.class.name, "redacted" => true }
    end
  end
end
