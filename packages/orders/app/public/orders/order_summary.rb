# frozen_string_literal: true

module Orders
  class OrderSummary
    attr_reader :shop_id, :source, :external_order_id, :state

    def initialize(shop_id:, source:, external_order_id:, state:)
      raise ArgumentError, "Invalid order summary" unless shop_id.is_a?(Integer) && shop_id.positive?
      @shop_id = shop_id
      @source = copy_text(source)
      @external_order_id = copy_text(external_order_id)
      @state = copy_text(state)
      freeze
    end

    def inspect
      "#<Orders::OrderSummary [REDACTED]>"
    end

    alias_method :to_s, :inspect

    private

    def copy_text(value)
      unless value.is_a?(String) && value.valid_encoding? && value.bytesize <= 255 &&
        !value.strip.empty? && !value.match?(/[[:cntrl:]]/)
        raise ArgumentError, "Invalid order summary"
      end
      value.encode(Encoding::UTF_8).freeze
    rescue EncodingError
      raise ArgumentError, "Invalid order summary", cause: nil
    end
  end
end
