# frozen_string_literal: true

module EventLedger
  class ReceivedEvent < Record
    self.table_name = "received_events"
  end
end
