# frozen_string_literal: true

require "base64"
require "openssl"

module Webhooks
  class ShopifyAuthenticator
    def call(raw_body:, headers:, source_configuration:)
      return false unless raw_body.is_a?(String) && headers.is_a?(Hash) &&
        source_configuration.instance_of?(ShopifySource)

      signatures = headers.select { |key, _| key.is_a?(String) && key.casecmp?("X-Shopify-Hmac-Sha256") }.values
      return false unless signatures.length == 1 && signatures.first.is_a?(String)
      signature = Base64.strict_decode64(signatures.first)
      return false unless signature.bytesize == 32

      expected = OpenSSL::HMAC.digest("SHA256", source_configuration.secret, raw_body)
      OpenSSL.fixed_length_secure_compare(expected, signature)
    rescue StandardError
      false
    end
  end
end
