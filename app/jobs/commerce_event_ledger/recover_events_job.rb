# frozen_string_literal: true

module CommerceEventLedger
  class RecoverEventsJob < ApplicationJob
    queue_as :commerce_events
    self.log_arguments = false

    def perform
      EventLedger::ProcessingStore.eligible_event_ids.each do |shop_id, event_id|
        ProcessEventJob.perform_later(shop_id, event_id)
      end
    end
  end
end
