# frozen_string_literal: true

module EventLedger
  class Claim
    include Contract::Redacted
    attr_reader :event, :token, :attempt_number

    def initialize(event:, token:, attempt_number:)
      Contract.invalid! unless event.instance_of?(PersistedEvent) && token.is_a?(String) && token.match?(/\A[0-9a-f]{64}\z/)
      @event = event
      @token = token.dup.freeze
      @attempt_number = Contract.positive_id(attempt_number)
      freeze
    end
  end
end
