# frozen_string_literal: true

require "digest/sha2"

module Webhooks
  class Ingress
    class AuthenticationError < StandardError; end
    class ReceiptError < StandardError; end

    def initialize(authenticator:, normalizer:, ledger:, registry:)
      unless authenticator.respond_to?(:call) && normalizer.respond_to?(:call) &&
        ledger.respond_to?(:receive) && registry.instance_of?(EventLedger::HandlerRegistry)
        raise ArgumentError, "Explicit webhook collaborators are required"
      end
      @authenticator = authenticator
      @normalizer = normalizer
      @ledger = ledger
      @registry = registry
      freeze
    end

    def call(raw_body:, headers:, source_configuration:)
      unless raw_body.is_a?(String) && headers.is_a?(Hash) &&
        source_configuration.respond_to?(:shop_id) && source_configuration.respond_to?(:source)
        raise ReceiptError, "Webhook receipt failed"
      end
      body = raw_body.dup.freeze
      request_headers = copy_headers(headers)
      authenticate!(body, request_headers, source_configuration)

      envelope = @normalizer.call(raw_body: body, headers: request_headers,
        source_configuration: source_configuration)
      unless envelope.instance_of?(EventLedger::Envelope) &&
        envelope.shop_id == source_configuration.shop_id && envelope.source == source_configuration.source &&
        envelope.payload_sha256 == Digest::SHA256.hexdigest(body)
        raise ReceiptError, "Webhook receipt failed"
      end

      entry = @registry.select(source: envelope.source, topic: envelope.topic)
      # The receipt adapter must assign this identity once durably. Duplicate
      # receipt preserves its existing identity even after registry changes.
      receipt = @ledger.receive(envelope: envelope,
        handler_name: entry.handler_name, handler_version: entry.handler_version)
      unless receipt.instance_of?(EventLedger::Receipt) && receipt.shop_id == envelope.shop_id
        raise ReceiptError, "Webhook receipt failed"
      end
      receipt
    rescue AuthenticationError
      raise
    rescue StandardError
      raise ReceiptError, "Webhook receipt failed", cause: nil
    end

    def inspect
      "#<Webhooks::Ingress [REDACTED]>"
    end

    alias_method :to_s, :inspect

    private

    def authenticate!(body, headers, configuration)
      authenticated = @authenticator.call(raw_body: body, headers: headers,
        source_configuration: configuration)
      raise AuthenticationError, "Webhook authentication failed" unless authenticated.equal?(true)
    rescue StandardError
      raise AuthenticationError, "Webhook authentication failed", cause: nil
    end

    def copy_headers(headers)
      headers.each_with_object({}) do |(key, value), result|
        unless key.is_a?(String) && value.is_a?(String)
          raise ReceiptError, "Webhook receipt failed"
        end
        result[key.dup.freeze] = value.dup.freeze
      end.freeze
    end
  end
end
