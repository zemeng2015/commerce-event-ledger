# frozen_string_literal: true

require "test_helper"
require "socket"
require "timeout"
require "stringio"
require "open3"

class FixturePublisherTest < ActiveSupport::TestCase
  test "actual HTTP bodies and signatures are exact and duplicates retain event identity" do
    captured = []
    with_receiver(count: 3, captured: captured) do |url|
      result = publisher.call(url: url, count: 3)
      assert_equal 3, result.fetch(:accepted)
    end
    body = File.binread(Rails.root.join("fixtures/shopify/orders_create.json"))
    signature = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", "test-signing-secret", body))
    captured.each do |headers, received|
      assert_equal body, received
      assert_equal signature, headers.fetch("x-shopify-hmac-sha256")
      assert_equal "application/json", headers.fetch("content-type")
      assert_equal "orders/create", headers.fetch("x-shopify-topic")
    end
    assert_equal 1, captured.map { |headers, _| headers.fetch("x-shopify-event-id") }.uniq.size
    assert_equal 3, captured.map { |headers, _| headers.fetch("x-shopify-webhook-id") }.uniq.size
  end

  test "nonaccepted and redirect responses fail without leaking response details" do
    [ 302, 500, 200 ].each do |status|
      with_receiver(count: 1, status: status) do |url|
        error = assert_raises(CommerceEventLedger::FixturePublisher::PublishError) { publisher.call(url: url, count: 2) }
        assert_nil error.cause
        refute_includes error.full_message, "synthetic-response-secret"
      end
    end
  end

  test "dry run is deterministic and exposes neither signatures nor secret" do
    first = publisher.call(dry_run: true)
    assert_equal first, publisher.call(dry_run: true)
    assert_equal 0, first.fetch(:accepted)
    assert_equal "dry-run", first.fetch(:mode)
    assert_equal "ed628f21-0845-4fa8-86a2-55e14f624ab2", first.fetch(:event_id)
    assert_equal true, publisher.as_json.fetch("redacted")
    refute_includes publisher.inspect, "test-signing-secret"
    alternate = publisher.call(dry_run: true, event_id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", url: "http://[::1]:3000/fixture")
    assert_equal "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", alternate.fetch(:event_id)
  end

  test "invalid destinations counts and identities fail before transport" do
    [ "https://127.0.0.1/", "http://example.com/", "http://localhost/", "http://127.0.0.1@elsewhere/",
      "http://user:password@127.0.0.1/", "http://127.0.0.1/?secret=x", "http://127.0.0.1/#x", "not a url" ].each do |url|
      assert_raises(CommerceEventLedger::FixturePublisher::PublishError) { publisher.call(url: url, dry_run: true) }
    end
    [ 0, 101, "2", nil ].each do |count|
      assert_raises(CommerceEventLedger::FixturePublisher::PublishError) { publisher.call(count: count, dry_run: true) }
    end
    assert_raises(CommerceEventLedger::FixturePublisher::PublishError) { publisher.call(event_id: "bad", dry_run: true) }
    assert_raises(CommerceEventLedger::FixturePublisher::PublishError) { CommerceEventLedger::FixturePublisher.new(secret: "") }
  end

  test "CLI rejects invalid flags and sanitizes all diagnostics" do
    [ [ "--unknown", "synthetic-secret-marker" ], [ "extra" ], [ "--count", "bad" ], [ "--event-id", "synthetic-secret-marker", "--dry-run" ] ].each do |arguments|
      out = StringIO.new
      err = StringIO.new
      assert_equal 1, CommerceEventLedger::FixturePublisher.run(arguments, out: out, err: err, environment: {})
      assert_empty out.string
      refute_includes err.string, "synthetic-secret-marker"
    end
    out = StringIO.new
    assert_equal 0, CommerceEventLedger::FixturePublisher.run([ "--dry-run", "--count", "2" ], out: out, environment: { "LEDGER_FIXTURE_SECRET" => "synthetic-secret-marker" })
    assert_equal 2, JSON.parse(out.string).fetch("count")
    refute_includes out.string, "synthetic-secret-marker"
  end

  test "standalone command does not boot Rails or use inherited database configuration" do
    output, status = Open3.capture2e({ "RAILS_ENV" => "production", "DATABASE_URL" => "mysql2://invalid@127.0.0.1:1/not_a_database" },
      RbConfig.ruby, Rails.root.join("bin/publish_fixture").to_s, "--dry-run")
    assert status.success?, output
    assert_equal "dry-run", JSON.parse(output).fetch("mode")
  end

  private

  def publisher
    CommerceEventLedger::FixturePublisher.new(secret: "test-signing-secret")
  end

  def with_receiver(count:, status: 202, captured: [])
    server = TCPServer.new("127.0.0.1", 0)
    worker = Thread.new do
      count.times do
        Timeout.timeout(5) do
          socket = server.accept
          begin
            socket.gets
            headers = {}
            while (line = socket.gets) && line != "\r\n"
              name, value = line.split(":", 2)
              headers[name.downcase] = value.strip
            end
            captured << [ headers, socket.read(Integer(headers.fetch("content-length"))) ]
            body = "synthetic-response-secret"
            socket.write("HTTP/1.1 #{status} Test\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\nLocation: http://example.com/\r\n\r\n#{body}")
          ensure
            socket.close
          end
        end
      end
    end
    worker.report_on_exception = false
    yield "http://127.0.0.1:#{server.addr[1]}/fixture"
    assert worker.join(6), "Loopback receiver did not finish"
    worker.value
  ensure
    server&.close
    worker&.join(6)
  end
end
