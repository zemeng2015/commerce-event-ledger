# frozen_string_literal: true

module CommerceEventLedger
  class ProcessEventJob < ApplicationJob
    queue_as :commerce_events
    self.log_arguments = false

    def perform(shop_id, event_id)
      store = EventLedger::ProcessingStore.new(shop_id: shop_id)
      claim = store.claim(event_id: event_id)
      return unless claim

      begin
        Orders::Handler.new(effect_executor: Orders::EffectExecutor.new).call(event: claim.event)
      rescue StandardError
        store.fail(claim: claim)
        return
      end
      store.finish(claim: claim)
    end
  end
end
