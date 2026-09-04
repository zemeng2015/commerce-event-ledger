# frozen_string_literal: true

module EventLedger
  # Private copying/validation for this package's immutable values only.
  module Contract
    module Redacted
      def inspect
        "#<#{self.class.name} [REDACTED]>"
      end

      alias_method :to_s, :inspect

      def as_json(_options = nil)
        { "type" => self.class.name, "redacted" => true }
      end
    end

    module_function

    def invalid!
      raise ArgumentError, "Invalid event contract", cause: nil
    end

    def positive_id(value)
      invalid! unless value.is_a?(Integer) && value.positive?
      value
    end

    def text(value)
      invalid! unless value.is_a?(String) && value.valid_encoding? &&
        value.bytesize <= 255 && !value.strip.empty? && !value.match?(/[[:cntrl:]]/)
      copy_string(value)
    end

    def boolean(value)
      invalid! unless value.equal?(true) || value.equal?(false)
      value
    end

    def timestamp(value)
      invalid! unless value.is_a?(Time)
      value.getutc.freeze
    end

    def version(value)
      return nil if value.nil?
      return value if value.is_a?(Integer) && value >= 0
      text(value)
    end

    def digest(value)
      invalid! unless value.is_a?(String) && value.ascii_only? && value.match?(/\A[0-9a-f]{64}\z/)
      value.dup.freeze
    end

    def json_object(value)
      invalid! unless value.is_a?(Hash)
      copy_json(value)
    end

    def copy_string(value)
      invalid! unless value.valid_encoding?
      value.encode(Encoding::UTF_8).freeze
    rescue EncodingError
      invalid!
    end

    def copy_json(value, ancestors = {}, depth = 0)
      invalid! if depth > 64

      case value
      when Hash, Array
        invalid! if ancestors.key?(value.object_id)
        ancestors[value.object_id] = true
        begin
          if value.is_a?(Hash)
            value.each_with_object({}) do |(key, item), result|
              invalid! unless key.is_a?(String)
              result[copy_string(key)] = copy_json(item, ancestors, depth + 1)
            end.freeze
          else
            value.map { |item| copy_json(item, ancestors, depth + 1) }.freeze
          end
        ensure
          ancestors.delete(value.object_id)
        end
      when String
        copy_string(value)
      when Integer, TrueClass, FalseClass, NilClass
        value
      when Float
        invalid! unless value.finite?
        value
      else
        invalid!
      end
    end
  end
end
