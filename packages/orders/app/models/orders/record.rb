# frozen_string_literal: true

module Orders
  class Record < ActiveRecord::Base
    self.abstract_class = true
  end
end
