# frozen_string_literal: true

module Orders
  class Handler
    class ExecutionError < StandardError; end

    NAME = "order_projection"
    VERSION = "v1"
    SOURCE = "shopify"
    TOPIC = "orders/create"

    def initialize(effect_executor:)
      raise ArgumentError, "An effect executor is required" unless effect_executor.respond_to?(:call)
      @effect_executor = effect_executor
      freeze
    end

    def handler_name
      NAME
    end

    def handler_version
      VERSION
    end

    def call(event:)
      unless event.instance_of?(EventLedger::PersistedEvent) &&
        event.handler_name == NAME && event.handler_version == VERSION &&
        event.envelope.source == SOURCE && event.envelope.topic == TOPIC
        raise ArgumentError, "A persisted event with the exact order handler identity and route is required"
      end

      # The Orders adapter owns one primary-MySQL transaction for projection
      # and effect. There is deliberately no default executor or success value.
      begin
        result = @effect_executor.call(event: event)
        unless result.instance_of?(EventLedger::EffectResult)
          raise ExecutionError, "Order effect execution failed"
        end
        result
      rescue StandardError
        raise ExecutionError, "Order effect execution failed", cause: nil
      end
    end

    def inspect
      "#<Orders::Handler [REDACTED]>"
    end

    alias_method :to_s, :inspect

    def as_json(_options = nil)
      { "type" => self.class.name, "redacted" => true }
    end
  end
end
