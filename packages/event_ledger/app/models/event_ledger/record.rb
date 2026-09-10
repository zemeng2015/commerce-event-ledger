# frozen_string_literal: true

module EventLedger
  class Record < ActiveRecord::Base
    self.abstract_class = true
  end
end
