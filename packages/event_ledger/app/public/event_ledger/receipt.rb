# frozen_string_literal: true

module EventLedger
  # A receipt port may return this only after durable receipt commits. This
  # value itself performs no persistence and says nothing about processing.
  class Receipt
    include Contract::Redacted

    attr_reader :event_id, :shop_id, :duplicate

    def initialize(event_id:, shop_id:, duplicate:)
      @event_id = Contract.positive_id(event_id)
      @shop_id = Contract.positive_id(shop_id)
      @duplicate = Contract.boolean(duplicate)
      freeze
    end
  end
end
