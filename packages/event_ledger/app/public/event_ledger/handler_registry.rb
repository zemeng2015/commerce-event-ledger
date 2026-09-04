# frozen_string_literal: true

module EventLedger
  class HandlerRegistry
    include Contract::Redacted

    class Entry
      include Contract::Redacted

      attr_reader :source, :topic, :handler_name, :handler_version, :handler

      def initialize(source:, topic:, handler:)
        Contract.invalid! unless handler.respond_to?(:call) &&
          handler.respond_to?(:handler_name) && handler.respond_to?(:handler_version)
        @source = Contract.text(source)
        @topic = Contract.text(topic)
        @handler_name = Contract.text(handler.handler_name)
        @handler_version = Contract.text(handler.handler_version)
        @handler = handler
        freeze
      end
    end

    attr_reader :entries

    def initialize(entries:)
      Contract.invalid! unless entries.is_a?(Array) && !entries.empty? &&
        entries.all? { |entry| entry.instance_of?(Entry) }
      @entries = entries.dup.freeze
      @by_route = {}
      @by_identity = {}

      @entries.each do |entry|
        route = [ entry.source, entry.topic ].freeze
        identity = [ entry.handler_name, entry.handler_version ].freeze
        raise ArgumentError, "Duplicate handler route" if @by_route.key?(route)
        raise ArgumentError, "Duplicate handler identity" if @by_identity.key?(identity)
        @by_route[route] = entry
        @by_identity[identity] = entry
      end

      @by_route.freeze
      @by_identity.freeze
      freeze
    end

    def select(source:, topic:)
      @by_route.fetch([ Contract.text(source), Contract.text(topic) ]) do
        raise KeyError, "No handler is registered for this event route"
      end
    end

    def fetch(handler_name:, handler_version:)
      @by_identity.fetch([ Contract.text(handler_name), Contract.text(handler_version) ]) do
        raise KeyError, "The exact persisted handler identity is not registered"
      end
    end
  end
end
