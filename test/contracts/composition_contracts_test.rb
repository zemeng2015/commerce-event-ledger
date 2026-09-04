# frozen_string_literal: true

require "test_helper"
require "digest/sha2"

class CompositionContractsTest < ActiveSupport::TestCase
  TestOnlySourceConfiguration = Struct.new(:shop_id, :source, :secret, keyword_init: true)

  class TestOnlyAuthenticator
    attr_reader :input
    attr_accessor :verdict, :error

    def initialize(log:)
      @log = log
      @verdict = true
    end

    def call(**input)
      @log << :authenticate
      @input = input
      raise @error if @error
      @verdict
    end
  end

  class TestOnlyNormalizer
    attr_reader :input
    attr_accessor :envelope, :error

    def initialize(log:, envelope:)
      @log = log
      @envelope = envelope
    end

    def call(**input)
      @log << :normalize
      @input = input
      raise @error if @error
      @envelope
    end
  end

  class TestOnlyReceiptPort
    attr_reader :input
    attr_accessor :receipt, :error

    def initialize(log:)
      @log = log
      @receipt = EventLedger::Receipt.new(event_id: 101, shop_id: 7, duplicate: false)
    end

    def receive(**input)
      @log << :receive
      @input = input
      raise @error if @error
      @receipt
    end
  end

  class TestOnlyEffectExecutor
    attr_reader :events
    attr_accessor :result, :error

    def initialize
      @events = []
      @result = EventLedger::EffectResult.new(effect_id: 301, outcome: :applied, duplicate: false)
    end

    def call(event:)
      @events << event
      raise @error if @error
      @result
    end
  end

  class TestOnlyReader
    attr_reader :calls
    attr_accessor :result, :error

    def initialize(result:)
      @calls = []
      @result = result
    end

    def find(**input)
      @calls << input
      raise @error if @error
      @result
    end
  end

  setup do
    @log = []
    @raw_body = +'{"id":"order-42"}'
    @headers = { "X-Test-Signature" => +"synthetic-signature-marker" }
    @configuration = TestOnlySourceConfiguration.new(shop_id: 7, source: +"shopify", secret: "synthetic-secret-marker")
    @authenticator = TestOnlyAuthenticator.new(log: @log)
    @normalizer = TestOnlyNormalizer.new(log: @log, envelope: envelope)
    @ledger = TestOnlyReceiptPort.new(log: @log)
    @executor = TestOnlyEffectExecutor.new
    @event_reader = TestOnlyReader.new(result: EventLedger::EventSummary.new(event_id: 101, shop_id: 7, status: "processed"))
    @order_reader = TestOnlyReader.new(result: Orders::OrderSummary.new(shop_id: 7, source: "shopify", external_order_id: "order-42", state: "created"))
    @composition = composition
  end

  test "composed ports route receipt exact-identity dispatch and tenant-scoped queries" do
    receipt = receive
    assert_equal [ :authenticate, :normalize, :receive ], @log
    assert_equal 101, receipt.event_id
    assert_equal 7, receipt.shop_id
    assert_equal "order_projection", @ledger.input.fetch(:handler_name)
    assert_equal "v1", @ledger.input.fetch(:handler_version)
    assert @ledger.input.fetch(:handler_name).frozen?
    assert @ledger.input.fetch(:handler_version).frozen?

    # This test-only receipt port does not persist. Reconstruct the handler input
    # explicitly from its captured contract to verify wiring, not durability.
    event = persisted_event(envelope: @ledger.input.fetch(:envelope),
      handler_name: @ledger.input.fetch(:handler_name), handler_version: @ledger.input.fetch(:handler_version))
    result = @composition.dispatch(event: event)
    assert_same @executor.result, result
    assert_equal [ event ], @executor.events

    queries = @composition.queries(shop_id: 7)
    assert_same @event_reader.result, queries.event(event_id: receipt.event_id)
    assert_same @order_reader.result, queries.order(source: "shopify", external_order_id: "order-42")
    assert_equal [ { shop_id: 7, event_id: 101 } ], @event_reader.calls
    assert_equal [ { shop_id: 7, source: "shopify", external_order_id: "order-42" } ], @order_reader.calls
  end

  test "ingress uses an exact immutable body and header snapshot for both ports" do
    receive
    authenticated_body = @authenticator.input.fetch(:raw_body)
    normalized_body = @normalizer.input.fetch(:raw_body)
    assert_same authenticated_body, normalized_body
    assert_equal @raw_body.b, authenticated_body.b
    assert authenticated_body.frozen?
    refute_same @raw_body, authenticated_body
    @raw_body.replace("changed after call")
    @headers.fetch("X-Test-Signature").replace("changed after call")
    assert_equal '{"id":"order-42"}', authenticated_body
    assert_equal "synthetic-signature-marker", @authenticator.input.fetch(:headers).fetch("X-Test-Signature")
    assert @authenticator.input.fetch(:headers).frozen?
  end

  test "authentication is fail closed for false nil and truthy non-boolean responses" do
    [ false, nil, "true" ].each do |verdict|
      @log.clear
      @authenticator.verdict = verdict
      assert_raises(Webhooks::Ingress::AuthenticationError) { receive }
      assert_equal [ :authenticate ], @log
      assert_nil @ledger.input
    end
  end

  test "authentication errors are redacted before normalization and receipt" do
    @authenticator.error = RuntimeError.new("synthetic-secret-marker")
    error = assert_raises(Webhooks::Ingress::AuthenticationError) { receive }
    assert_equal [ :authenticate ], @log
    refute_includes error.full_message, "synthetic-secret-marker"
    assert_nil error.cause
  end

  test "normalizer and receipt ports cannot leak their own public authentication errors" do
    [ @normalizer, @ledger ].each do |collaborator|
      collaborator.error = Webhooks::Ingress::AuthenticationError.new("synthetic-secret-marker")
      error = assert_raises(Webhooks::Ingress::AuthenticationError) { receive }
      assert_equal "Webhook authentication failed", error.message
      refute_includes error.full_message, "synthetic-secret-marker"
      assert_nil error.cause
      collaborator.error = nil
    end
  end

  test "normalizer output must match the trusted tenant source and exact raw digest" do
    [ { shop_id: 8 }, { source: "another-source" }, { payload_sha256: "0" * 64 } ].each do |changes|
      @log.clear
      @normalizer.envelope = envelope(**changes)
      assert_raises(Webhooks::Ingress::ReceiptError) { receive }
      assert_equal [ :authenticate, :normalize ], @log
      assert_nil @ledger.input
    end
  end

  test "malformed normalization or an unsupported route cannot reach receipt" do
    [ { "raw_payload" => "synthetic-secret-marker" }, envelope(topic: "orders/updated") ].each do |value|
      @log.clear
      @normalizer.envelope = value
      error = assert_raises(Webhooks::Ingress::ReceiptError) { receive }
      assert_equal [ :authenticate, :normalize ], @log
      assert_nil @ledger.input
      refute_includes error.full_message, "synthetic-secret-marker"
    end
  end

  test "receipt output must be a public receipt for the trusted tenant" do
    [ Object.new, EventLedger::Receipt.new(event_id: 101, shop_id: 8, duplicate: false) ].each do |value|
      @ledger.receipt = value
      assert_raises(Webhooks::Ingress::ReceiptError) { receive }
    end
  end

  test "duplicate receipt flag is forwarded without inventing processing success" do
    @ledger.receipt = EventLedger::Receipt.new(event_id: 101, shop_id: 7, duplicate: true)
    assert receive.duplicate
    assert_empty @executor.events
  end

  test "composition builds new reloadable registry handler and query objects" do
    first = @composition.handler_registry
    second = @composition.handler_registry
    refute_same first, second
    refute_same first.entries.first.handler, second.entries.first.handler
    refute_same @composition.ingress, @composition.ingress
    refute_same @composition.queries(shop_id: 7), @composition.queries(shop_id: 7)
  end

  test "dispatch rejects missing exact persisted identity instead of using the latest handler" do
    assert_raises(KeyError) { @composition.dispatch(event: persisted_event(handler_version: "v2")) }
    assert_raises(ArgumentError) { @composition.dispatch(event: envelope) }
    assert_empty @executor.events
  end

  test "order handler rejects envelopes mismatched identities and unsupported routes before execution" do
    handler = Orders::Handler.new(effect_executor: @executor)
    [ envelope, persisted_event(handler_name: "another_handler"),
      persisted_event(handler_version: "v2"), persisted_event(envelope: envelope(topic: "orders/updated")) ].each do |value|
      assert_raises(ArgumentError) { handler.call(event: value) }
    end
    assert_empty @executor.events
  end

  test "order handler requires a real injected executor and a public effect result" do
    assert_raises(ArgumentError) { Orders::Handler.new(effect_executor: nil) }
    @executor.result = { "effect_id" => 301 }
    assert_raises(Orders::Handler::ExecutionError) { @composition.dispatch(event: persisted_event) }
  end

  test "executor failures are redacted rather than becoming a default success" do
    @executor.error = RuntimeError.new("synthetic-secret-marker")
    error = assert_raises(Orders::Handler::ExecutionError) { @composition.dispatch(event: persisted_event) }
    refute_includes error.full_message, "synthetic-secret-marker"
    assert_nil error.cause
  end

  test "duplicate stale effect results preserve their recorded outcome" do
    @executor.result = EventLedger::EffectResult.new(effect_id: 301, outcome: :stale, duplicate: true)
    result = @composition.dispatch(event: persisted_event)
    assert_equal :stale, result.outcome
    assert result.duplicate
    assert_equal 301, result.effect_id
  end

  test "queries require a positive bound tenant and explicit readers" do
    [ nil, 0, -1, "7" ].each do |shop_id|
      assert_raises(ArgumentError) { @composition.queries(shop_id: shop_id) }
    end
    assert_raises(ArgumentError) do
      Operations::Queries.new(shop_id: 7, event_reader: nil, order_reader: @order_reader)
    end
    assert_empty @event_reader.calls
    assert_empty @order_reader.calls
  end

  test "queries reject invalid identifiers before reader invocation" do
    queries = @composition.queries(shop_id: 7)
    [ nil, 0, "101" ].each { |id| assert_raises(ArgumentError) { queries.event(event_id: id) } }
    assert_raises(ArgumentError) { queries.order(source: "", external_order_id: "order-42") }
    assert_raises(ArgumentError) { queries.order(source: "shopify", external_order_id: nil) }
    assert_empty @event_reader.calls
    assert_empty @order_reader.calls
  end

  test "event query rejects cross-tenant mismatched and raw reader results" do
    queries = @composition.queries(shop_id: 7)
    [ EventLedger::EventSummary.new(event_id: 101, shop_id: 8, status: "processed"),
      EventLedger::EventSummary.new(event_id: 102, shop_id: 7, status: "processed"),
      { "raw_payload" => "synthetic-secret-marker" }, Object.new ].each do |value|
      @event_reader.result = value
      assert_raises(Operations::Queries::ReadError) { queries.event(event_id: 101) }
    end
  end

  test "order query rejects cross-tenant source identity and raw reader mismatches" do
    queries = @composition.queries(shop_id: 7)
    [ { shop_id: 8 }, { source: "another-source" }, { external_order_id: "another-order" } ].each do |changes|
      @order_reader.result = Orders::OrderSummary.new(**{ shop_id: 7, source: "shopify", external_order_id: "order-42", state: "created" }.merge(changes))
      assert_raises(Operations::Queries::ReadError) { queries.order(source: "shopify", external_order_id: "order-42") }
    end
    @order_reader.result = Object.new
    assert_raises(Operations::Queries::ReadError) { queries.order(source: "shopify", external_order_id: "order-42") }
  end

  test "missing reader results are nil with the bound tenant still forwarded" do
    @event_reader.result = nil
    @order_reader.result = nil
    queries = @composition.queries(shop_id: 7)
    assert_nil queries.event(event_id: 101)
    assert_nil queries.order(source: "shopify", external_order_id: "order-42")
    assert_equal 7, @event_reader.calls.last.fetch(:shop_id)
    assert_equal 7, @order_reader.calls.last.fetch(:shop_id)
  end

  test "reader errors and collaborator inspection are redacted" do
    @event_reader.error = RuntimeError.new("synthetic-secret-marker")
    error = assert_raises(Operations::Queries::ReadError) { @composition.queries(shop_id: 7).event(event_id: 101) }
    refute_includes error.full_message, "synthetic-secret-marker"
    assert_nil error.cause

    [ @composition, @composition.ingress, @composition.queries(shop_id: 7), @composition.handler_registry.entries.first.handler ].each do |value|
      assert_includes value.inspect, "[REDACTED]"
      refute_includes value.inspect, "synthetic-secret-marker"
    end
  end

  test "summary values copy mutable strings and redact their fields" do
    state = +"created"
    status = +"processed"
    order = Orders::OrderSummary.new(shop_id: 7, source: "shopify", external_order_id: "order-42", state: state)
    event = EventLedger::EventSummary.new(event_id: 101, shop_id: 7, status: status)
    state.replace("changed")
    status.replace("changed")
    assert_equal "created", order.state
    assert_equal "processed", event.status
    assert order.frozen?
    assert order.state.frozen?
    assert event.frozen?
    assert event.status.frozen?
    refute_includes order.inspect, "created"
    refute_includes event.to_s, "processed"
  end

  test "summary states are finite and reject untrusted text without echoing it" do
    EventLedger::EventSummary::STATUSES.each do |status|
      value = EventLedger::EventSummary.new(event_id: 101, shop_id: 7, status: status)
      assert_equal status, value.status
      assert value.status.frozen?
    end

    [ "synthetic-secret-marker", "arbitrary-status", nil ].each do |invalid|
      event_error = assert_raises(ArgumentError) do
        EventLedger::EventSummary.new(event_id: 101, shop_id: 7, status: invalid)
      end
      order_error = assert_raises(ArgumentError) do
        Orders::OrderSummary.new(shop_id: 7, source: "shopify", external_order_id: "order-42", state: invalid)
      end
      refute_includes event_error.full_message, "synthetic-secret-marker"
      refute_includes order_error.full_message, "synthetic-secret-marker"
    end
  end

  test "queries reject raw secret status and state instead of publishing them" do
    @event_reader.result = { "status" => "synthetic-secret-marker" }
    @order_reader.result = { "state" => "synthetic-secret-marker" }
    queries = @composition.queries(shop_id: 7)
    event_error = assert_raises(Operations::Queries::ReadError) { queries.event(event_id: 101) }
    order_error = assert_raises(Operations::Queries::ReadError) do
      queries.order(source: "shopify", external_order_id: "order-42")
    end
    refute_includes event_error.full_message, "synthetic-secret-marker"
    refute_includes order_error.full_message, "synthetic-secret-marker"
  end

  test "default Rails JSON serialization cannot expose payloads or collaborators" do
    private_envelope = envelope(payload: { "secret" => "synthetic-secret-marker" })
    @normalizer.envelope = private_envelope
    registry = @composition.handler_registry
    values = [ private_envelope, persisted_event(envelope: private_envelope), @ledger.receipt,
      @executor.result, @event_reader.result, @order_reader.result, registry, registry.entries.first,
      registry.entries.first.handler, @composition, @composition.ingress, @composition.queries(shop_id: 7) ]

    values.each do |value|
      [ value.to_json, ActiveSupport::JSON.encode(value) ].each do |json|
        assert_equal true, JSON.parse(json).fetch("redacted")
        refute_includes json, "synthetic-secret-marker"
        refute_includes json, "synthetic-signature-marker"
        refute_includes json, "payload"
      end
    end
  end

  test "composition has no implicit collaborators" do
    assert_raises(ArgumentError) { CommerceEventLedger::Composition.new }
    assert_raises(ArgumentError) { composition(effect_executor: nil) }
  end

  private

  def composition(**overrides)
    CommerceEventLedger::Composition.new(**{
      authenticator: @authenticator, normalizer: @normalizer, ledger: @ledger,
      effect_executor: @executor, event_reader: @event_reader, order_reader: @order_reader
    }.merge(overrides))
  end

  def envelope(**overrides)
    EventLedger::Envelope.new(**{
      shop_id: 7, source: "shopify", external_event_id: "delivery-42", topic: "orders/create",
      subject_id: "order-42", occurred_at: Time.utc(2026, 9, 4),
      payload: { "id" => "order-42" }, payload_sha256: Digest::SHA256.hexdigest(@raw_body)
    }.merge(overrides))
  end

  def persisted_event(**overrides)
    EventLedger::PersistedEvent.new(**{
      event_id: 101, envelope: envelope, received_at: Time.utc(2026, 9, 4, 1),
      handler_name: "order_projection", handler_version: "v1"
    }.merge(overrides))
  end

  def receive
    @composition.ingress.call(raw_body: @raw_body, headers: @headers, source_configuration: @configuration)
  end
end
