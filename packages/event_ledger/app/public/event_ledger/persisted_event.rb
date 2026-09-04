# frozen_string_literal: true

module EventLedger
  # Reconstructed by a tenant-scoped storage adapter, including the exact
  # handler identity assigned durably when the canonical event was accepted.
  class PersistedEvent
    include Contract::Redacted

    attr_reader :event_id, :envelope, :received_at, :handler_name, :handler_version

    def initialize(event_id:, envelope:, received_at:, handler_name:, handler_version:)
      Contract.invalid! unless envelope.instance_of?(Envelope)
      @event_id = Contract.positive_id(event_id)
      @envelope = envelope
      @received_at = Contract.timestamp(received_at)
      @handler_name = Contract.text(handler_name)
      @handler_version = Contract.text(handler_version)
      freeze
    end
  end
end
