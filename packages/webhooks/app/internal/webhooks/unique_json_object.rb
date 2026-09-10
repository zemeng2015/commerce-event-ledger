# frozen_string_literal: true

module Webhooks
  class UniqueJsonObject < Hash
    def []=(key, value)
      raise ArgumentError, "Duplicate JSON key" if key?(key)
      super
    end
  end
end
