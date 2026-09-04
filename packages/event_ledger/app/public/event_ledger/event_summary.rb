# frozen_string_literal: true

module EventLedger
  # The read port returns this limited value or nil, never a model or relation.
  class EventSummary
    include Contract::Redacted

    STATUSES = %w[pending processing retry_wait processed dead_letter].freeze

    attr_reader :event_id, :shop_id, :status

    def initialize(event_id:, shop_id:, status:)
      @event_id = Contract.positive_id(event_id)
      @shop_id = Contract.positive_id(shop_id)
      @status = Contract.text(status)
      Contract.invalid! unless STATUSES.include?(@status)
      freeze
    end
  end
end
