# frozen_string_literal: true

module CommerceEventLedger
  # Reloadable request/execution wiring. Storage, HMAC and normalization adapters
  # are mandatory; this class never invents an in-memory or successful default.
  class Composition
    def initialize(authenticator:, normalizer:, ledger:, effect_executor:, event_reader:, order_reader:)
      @authenticator = authenticator
      @normalizer = normalizer
      @ledger = ledger
      @effect_executor = effect_executor
      @event_reader = event_reader
      @order_reader = order_reader
      freeze
    end

    def handler_registry
      handler = Orders::Handler.new(effect_executor: @effect_executor)
      entry = EventLedger::HandlerRegistry::Entry.new(source: Orders::Handler::SOURCE,
        topic: Orders::Handler::TOPIC, handler: handler)
      EventLedger::HandlerRegistry.new(entries: [ entry ])
    end

    def ingress
      Webhooks::Ingress.new(authenticator: @authenticator, normalizer: @normalizer,
        ledger: @ledger, registry: handler_registry)
    end

    def dispatch(event:)
      unless event.instance_of?(EventLedger::PersistedEvent)
        raise ArgumentError, "A persisted event is required"
      end
      entry = handler_registry.fetch(handler_name: event.handler_name, handler_version: event.handler_version)
      entry.handler.call(event: event)
    end

    def queries(shop_id:)
      Operations::Queries.new(shop_id: shop_id, event_reader: @event_reader, order_reader: @order_reader)
    end

    def inspect
      "#<CommerceEventLedger::Composition [REDACTED]>"
    end

    alias_method :to_s, :inspect
  end
end
