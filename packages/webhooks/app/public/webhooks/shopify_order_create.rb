# frozen_string_literal: true

require "json"
require "time"
require "date"
require "digest/sha2"

module Webhooks
  class ShopifyOrderCreate
    class NormalizationError < StandardError; end

    TIMESTAMP = /\A\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d{1,9})?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)\z/
    REQUIRED_HEADERS = %w[x-shopify-topic x-shopify-event-id x-shopify-shop-domain x-shopify-api-version].freeze

    def call(raw_body:, headers:, source_configuration:)
      invalid! unless source_configuration.instance_of?(ShopifySource) && raw_body.is_a?(String) &&
        raw_body.bytesize <= 1_048_576 && headers.is_a?(Hash)
      body = raw_body.dup.force_encoding(Encoding::UTF_8).freeze
      invalid! unless body.valid_encoding?
      metadata = required_headers(headers)
      invalid! unless metadata.fetch("x-shopify-topic") == "orders/create" &&
        metadata.fetch("x-shopify-api-version") == "2026-07" &&
        metadata.fetch("x-shopify-shop-domain") == source_configuration.shop_domain
      event_id = metadata.fetch("x-shopify-event-id")
      # The source event ID is opaque. Do not invent UUID or case-folding
      # semantics for identifiers supplied by the provider.
      invalid! unless event_id.ascii_only? && event_id.match?(/\A[!-~]{1,200}\z/)
      # Reject duplicates in UniqueJsonObject without JSON emitting input keys
      # to stderr before our sanitized normalization error is raised.
      order = JSON.parse(body, object_class: UniqueJsonObject, max_nesting: 64,
        allow_nan: false, create_additions: false, allow_duplicate_key: true)
      invalid! unless order.is_a?(Hash) && order["id"].is_a?(Integer) && order["id"].positive?
      created = timestamp(order.fetch("created_at"))
      updated = timestamp(order.fetch("updated_at"))
      invalid! if updated < created
      order_id = order.fetch("id").to_s
      EventLedger::Envelope.new(shop_id: source_configuration.shop_id, source: "shopify",
        external_event_id: "orders/create:#{event_id}", topic: "orders/create", subject_id: order_id,
        occurred_at: updated, source_version: nil, payload_sha256: Digest::SHA256.hexdigest(body),
        payload: { "order_id" => order_id, "state" => "created",
          "created_at" => created.iso8601(9), "updated_at" => updated.iso8601(9) })
    rescue StandardError
      raise NormalizationError, "Invalid Shopify order-create webhook", cause: nil
    end

    def inspect
      "#<Webhooks::ShopifyOrderCreate [REDACTED]>"
    end
    alias_method :to_s, :inspect

    def as_json(_options = nil)
      { "type" => self.class.name, "redacted" => true }
    end

    private

    def invalid!
      raise ArgumentError, "Invalid webhook shape"
    end

    def required_headers(headers)
      selected = {}
      headers.each do |key, value|
        invalid! unless key.is_a?(String) && key.ascii_only?
        name = key.downcase
        next unless REQUIRED_HEADERS.include?(name)
        invalid! if selected.key?(name) || !value.is_a?(String)
        selected[name] = value.dup.freeze
      end
      invalid! unless selected.size == REQUIRED_HEADERS.size
      selected
    end

    def timestamp(value)
      invalid! unless value.is_a?(String) && value.ascii_only? && value.match?(TIMESTAMP)
      year, month, day = value[0, 10].split("-").map(&:to_i)
      invalid! unless year.positive? && Date.valid_date?(year, month, day)
      Time.iso8601(value).utc
    end
  end
end
