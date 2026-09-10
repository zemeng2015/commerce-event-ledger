# frozen_string_literal: true

module EventLedger
  class ProcessingAttempt < Record
    self.table_name = "processing_attempts"
  end
end
