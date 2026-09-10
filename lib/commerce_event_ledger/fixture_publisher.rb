# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "base64"
require "securerandom"
require "optparse"
require "digest/sha2"

module CommerceEventLedger
  class FixturePublisher
    class PublishError < StandardError; end
    ROOT = File.expand_path("../..", __dir__)
    FIXTURE_SECRET = "ledger-fixture-secret-do-not-use-outside-local"
    DEFAULT_URL = "http://127.0.0.1:3000/webhooks/shopify/fixture"
    UUID = /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i

    def self.run(arguments, out: $stdout, err: $stderr, environment: ENV)
      options = { url: DEFAULT_URL, count: 1, dry_run: false }
      parser = OptionParser.new do |flags|
        flags.on("--url URL") { |value| options[:url] = value }
        flags.on("--count COUNT", Integer) { |value| options[:count] = value }
        flags.on("--event-id UUID") { |value| options[:event_id] = value }
        flags.on("--dry-run") { options[:dry_run] = true }
      end
      remaining = arguments.dup
      parser.parse!(remaining)
      raise PublishError unless remaining.empty?
      publisher = new(secret: environment.fetch("LEDGER_FIXTURE_SECRET", FIXTURE_SECRET))
      out.puts JSON.generate(publisher.call(**options))
      0
    rescue StandardError
      err.puts "Fixture publish failed; check local configuration and receiver."
      1
    end

    def initialize(secret:)
      raise PublishError, "Invalid fixture configuration" unless secret.is_a?(String) && !secret.empty?
      @secret = secret.dup.freeze
      freeze
    end

    def call(url: DEFAULT_URL, count: 1, event_id: nil, dry_run: false)
      uri = URI.parse(url)
      unless uri.scheme == "http" && %w[127.0.0.1 ::1].include?(uri.hostname) &&
        (1..65535).cover?(uri.port) &&
        uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil? &&
        count.is_a?(Integer) && (1..100).cover?(count) && [ true, false ].include?(dry_run)
        raise PublishError
      end
      body = File.binread(File.join(ROOT, "fixtures/shopify/orders_create.json")).freeze
      headers = JSON.parse(File.read(File.join(ROOT, "fixtures/shopify/orders_create_headers.json")))
      identity = event_id || headers.fetch("X-Shopify-Event-Id")
      raise PublishError unless identity.is_a?(String) && identity.ascii_only? && identity.match?(UUID)
      headers["X-Shopify-Event-Id"] = identity.downcase
      headers["Content-Type"] = "application/json"
      headers["X-Shopify-Hmac-Sha256"] = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", @secret, body))
      accepted = 0
      unless dry_run
        count.times do
          request = Net::HTTP::Post.new(uri.request_uri, headers)
          request["X-Shopify-Webhook-Id"] = SecureRandom.uuid
          request.body = body
          http = Net::HTTP.new(uri.hostname, uri.port, nil)
          http.open_timeout = 3
          http.read_timeout = 3
          http.write_timeout = 3
          http.max_retries = 0
          http.request(request) do |response|
            raise PublishError unless response.code == "202"
            # Do not retain or print receiver content, even on success.
            response.read_body { |_chunk| }
          end
          accepted += 1
        end
      end
      { mode: dry_run ? "dry-run" : "publish", event_id: identity.downcase, count: count,
        accepted: accepted, bytes: body.bytesize, body_sha256: Digest::SHA256.hexdigest(body) }
    rescue StandardError
      raise PublishError, "Fixture publish failed", cause: nil
    end

    def inspect
      "#<CommerceEventLedger::FixturePublisher [REDACTED]>"
    end
    alias_method :to_s, :inspect

    def as_json(_options = nil)
      { "type" => self.class.name, "redacted" => true }
    end
  end
end
