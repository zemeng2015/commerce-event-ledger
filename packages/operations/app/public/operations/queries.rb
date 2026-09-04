# frozen_string_literal: true

module Operations
  class Queries
    class ReadError < StandardError; end

    def initialize(shop_id:, event_reader:, order_reader:)
      unless shop_id.is_a?(Integer) && shop_id.positive? &&
        event_reader.respond_to?(:find) && order_reader.respond_to?(:find)
        raise ArgumentError, "A tenant and explicit public readers are required"
      end
      # A bound tenant is required input, not an authorization decision.
      @shop_id = shop_id
      @event_reader = event_reader
      @order_reader = order_reader
      freeze
    end

    def event(event_id:)
      raise ArgumentError, "Invalid event query" unless event_id.is_a?(Integer) && event_id.positive?

      begin
        result = @event_reader.find(shop_id: @shop_id, event_id: event_id)
        unless result.nil? || (result.instance_of?(EventLedger::EventSummary) &&
          result.shop_id == @shop_id && result.event_id == event_id)
          raise ReadError, "Event query failed"
        end
        result
      rescue StandardError
        raise ReadError, "Event query failed", cause: nil
      end
    end

    def order(source:, external_order_id:)
      source = query_text(source)
      external_order_id = query_text(external_order_id)

      begin
        result = @order_reader.find(shop_id: @shop_id, source: source, external_order_id: external_order_id)
        unless result.nil? || (result.instance_of?(Orders::OrderSummary) &&
          result.shop_id == @shop_id && result.source == source && result.external_order_id == external_order_id)
          raise ReadError, "Order query failed"
        end
        result
      rescue StandardError
        raise ReadError, "Order query failed", cause: nil
      end
    end

    def inspect
      "#<Operations::Queries [REDACTED]>"
    end

    alias_method :to_s, :inspect

    def as_json(_options = nil)
      { "type" => self.class.name, "redacted" => true }
    end

    private

    def query_text(value)
      unless value.is_a?(String) && value.valid_encoding? && value.bytesize <= 255 &&
        !value.strip.empty? && !value.match?(/[[:cntrl:]]/)
        raise ArgumentError, "Invalid order query"
      end
      value.encode(Encoding::UTF_8).freeze
    rescue EncodingError
      raise ArgumentError, "Invalid order query", cause: nil
    end
  end
end
