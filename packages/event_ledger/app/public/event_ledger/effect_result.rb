# frozen_string_literal: true

module EventLedger
  # A duplicate reports the original committed outcome; it is not a new effect.
  class EffectResult
    include Contract::Redacted

    attr_reader :effect_id, :outcome, :duplicate

    def initialize(effect_id:, outcome:, duplicate:)
      Contract.invalid! unless %i[applied stale].include?(outcome)
      @effect_id = Contract.positive_id(effect_id)
      @outcome = outcome
      @duplicate = Contract.boolean(duplicate)
      freeze
    end
  end
end
