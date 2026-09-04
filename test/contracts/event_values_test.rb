# frozen_string_literal: true

require "test_helper"

class EventValuesTest < ActiveSupport::TestCase
  test "an envelope copies and freezes its strings and timestamp" do
    attributes = envelope_attributes
    envelope = EventLedger::Envelope.new(**attributes)

    assert_predicate envelope, :frozen?
    %i[source external_event_id topic subject_id source_version payload_sha256].each do |name|
      original = attributes.fetch(name)
      copy = envelope.public_send(name)

      assert_equal original, copy
      refute_same original, copy
      assert_predicate copy, :frozen?
      refute_predicate original, :frozen?
      original.replace("changed after construction")
      refute_equal original, copy
      assert_raises(FrozenError) { copy.replace("changed inside envelope") }
    end

    assert_equal attributes.fetch(:occurred_at), envelope.occurred_at
    refute_same attributes.fetch(:occurred_at), envelope.occurred_at
    assert_predicate envelope.occurred_at, :frozen?
    refute_predicate attributes.fetch(:occurred_at), :frozen?
    attributes.fetch(:occurred_at).localtime("+01:00")
    assert_equal 0, envelope.occurred_at.utc_offset
    assert_raises(FrozenError) { envelope.occurred_at.localtime("+02:00") }
    assert_same attributes.fetch(:shop_id), envelope.shop_id
  end

  test "an envelope recursively copies and freezes JSON containers keys and strings" do
    attributes = envelope_attributes
    original = attributes.fetch(:payload)
    envelope = EventLedger::Envelope.new(**attributes)
    copy = envelope.payload

    assert_equal original, copy
    refute_same original, copy
    refute_same original.fetch("items"), copy.fetch("items")
    refute_same original.fetch("items").first, copy.fetch("items").first
    refute_same original.fetch("credentials"), copy.fetch("credentials")
    refute_same original.fetch("credentials").fetch("token"), copy.fetch("credentials").fetch("token")
    assert_deeply_frozen_json copy

    original.fetch("items").first.fetch("name").replace("changed item")
    original.fetch("credentials").fetch("token").replace("changed token")
    original.fetch("items") << { "name" => "another item" }
    original["after"] = "still mutable"

    assert_equal "synthetic item", copy.fetch("items").first.fetch("name")
    assert_equal private_marker, copy.fetch("credentials").fetch("token")
    assert_equal 1, copy.fetch("items").length
    refute copy.key?("after")
    assert_raises(FrozenError) { copy["after"] = "mutation" }
    assert_raises(FrozenError) { copy.fetch("items") << {} }
    assert_raises(FrozenError) { copy.fetch("items").first["name"] = "mutation" }
    assert_raises(FrozenError) { copy.fetch("credentials").fetch("token").replace("mutation") }
  end

  test "JSON scalar identities and supported source versions are preserved" do
    scalars = [ 7, 1.25, true, false, nil ]
    envelope = EventLedger::Envelope.new(**envelope_attributes.merge(payload: { "values" => scalars }))

    scalars.zip(envelope.payload.fetch("values")).each do |original, copy|
      if original.nil?
        assert_nil copy
      else
        assert_same original, copy
      end
    end

    [ nil, 0, 17 ].each do |version|
      value = EventLedger::Envelope.new(**envelope_attributes.merge(source_version: version))
      if version.nil?
        assert_nil value.source_version
      else
        assert_same version, value.source_version
      end
    end

    attributes = envelope_attributes
    attributes.delete(:source_version)
    assert_nil EventLedger::Envelope.new(**attributes).source_version
  end

  test "shared nested data without a cycle is valid and isolated from its input" do
    shared = { "token" => +private_marker }
    envelope = EventLedger::Envelope.new(**envelope_attributes.merge(payload: { "left" => shared, "right" => shared }))

    assert_equal shared, envelope.payload.fetch("left")
    assert_equal shared, envelope.payload.fetch("right")
    refute_same shared, envelope.payload.fetch("left")
    refute_same shared, envelope.payload.fetch("right")
    shared.fetch("token").replace("changed outside envelope")
    assert_equal private_marker, envelope.payload.fetch("left").fetch("token")
    assert_equal private_marker, envelope.payload.fetch("right").fetch("token")
  end

  test "an envelope requires a positive integer shop identifier" do
    invalid_identifiers.each do |identifier|
      assert_generic_argument_error do
        EventLedger::Envelope.new(**envelope_attributes.merge(shop_id: identifier))
      end
    end
  end

  test "an envelope requires nonblank string identifiers and topic" do
    %i[source external_event_id topic subject_id].each do |name|
      invalid_strings.each do |value|
        assert_generic_argument_error do
          EventLedger::Envelope.new(**envelope_attributes.merge(name => value))
        end
      end
    end
  end

  test "an envelope requires a Time timestamp" do
    [ nil, private_marker, 1, true ].each do |timestamp|
      assert_generic_argument_error do
        EventLedger::Envelope.new(**envelope_attributes.merge(occurred_at: timestamp))
      end
    end
  end

  test "an envelope rejects unsupported source versions" do
    [ -1, 1.5, "", " \t\n", true, false, [ private_marker ], { "token" => private_marker } ].each do |version|
      assert_generic_argument_error do
        EventLedger::Envelope.new(**envelope_attributes.merge(source_version: version))
      end
    end
  end

  test "an envelope requires a lowercase hexadecimal SHA256 digest" do
    [ nil, private_marker, "a" * 63, "a" * 65, "A" * 64, "g" * 64, "a" * 64 + "\n", 1 ].each do |digest|
      assert_generic_argument_error do
        EventLedger::Envelope.new(**envelope_attributes.merge(payload_sha256: digest))
      end
    end
  end

  test "an envelope requires a JSON object with string keys and finite JSON values" do
    invalid_payloads = [
      nil, [], private_marker,
      { token: private_marker },
      { "nested" => { 1 => private_marker } },
      { "nested" => [ { "token" => :unsupported } ] },
      { "nested" => [ Object.new ] },
      { "number" => Float::NAN },
      { "number" => Float::INFINITY },
      { "number" => -Float::INFINITY }
    ]

    invalid_payloads.each do |payload|
      assert_generic_argument_error do
        EventLedger::Envelope.new(**envelope_attributes.merge(payload: payload))
      end
    end
  end

  test "cyclic hashes are rejected with a generic argument error" do
    payload = { "token" => private_marker }
    payload["self"] = payload

    assert_generic_argument_error do
      EventLedger::Envelope.new(**envelope_attributes.merge(payload: payload))
    end
    refute_predicate payload, :frozen?
  end

  test "cyclic arrays and mixed container cycles are rejected with generic argument errors" do
    array = [ private_marker ]
    array << array
    payload = { "token" => private_marker }
    payload["nested"] = [ payload ]

    [ { "items" => array }, payload ].each do |cyclic_payload|
      assert_generic_argument_error do
        EventLedger::Envelope.new(**envelope_attributes.merge(payload: cyclic_payload))
      end
      refute_predicate cyclic_payload, :frozen?
    end
    refute_predicate array, :frozen?
  end

  test "receipts preserve strict boolean duplicate flags and scalar identifiers" do
    [ true, false ].each do |duplicate|
      receipt = EventLedger::Receipt.new(event_id: 12, shop_id: 7, duplicate: duplicate)

      assert_predicate receipt, :frozen?
      assert_same 12, receipt.event_id
      assert_same 7, receipt.shop_id
      assert_same duplicate, receipt.duplicate
    end
  end

  test "receipts reject invalid identifiers and nonboolean duplicate flags" do
    %i[event_id shop_id].each do |name|
      invalid_identifiers.each do |identifier|
        assert_generic_argument_error do
          EventLedger::Receipt.new(**{ event_id: 12, shop_id: 7, duplicate: false }.merge(name => identifier))
        end
      end
    end

    [ nil, 0, 1, "false", private_marker, :true ].each do |duplicate|
      assert_generic_argument_error do
        EventLedger::Receipt.new(event_id: 12, shop_id: 7, duplicate: duplicate)
      end
    end
  end

  test "persisted events preserve the envelope and isolate mutable metadata" do
    attributes = persisted_event_attributes
    event = EventLedger::PersistedEvent.new(**attributes)

    assert_predicate event, :frozen?
    assert_same attributes.fetch(:event_id), event.event_id
    assert_same attributes.fetch(:envelope), event.envelope
    %i[handler_name handler_version received_at].each do |name|
      assert_equal attributes.fetch(name), event.public_send(name)
      refute_same attributes.fetch(name), event.public_send(name)
      assert_predicate event.public_send(name), :frozen?
      refute_predicate attributes.fetch(name), :frozen?
    end

    attributes.fetch(:handler_name).replace("changed handler")
    attributes.fetch(:handler_version).replace("changed version")
    attributes.fetch(:received_at).localtime("+01:00")
    assert_equal "orders.create", event.handler_name
    assert_equal "v1", event.handler_version
    assert_equal 0, event.received_at.utc_offset
    assert_raises(FrozenError) { event.handler_name.replace("mutation") }
    assert_raises(FrozenError) { event.handler_version.replace("mutation") }
    assert_raises(FrozenError) { event.received_at.localtime("+02:00") }
  end

  test "persisted events reject invalid identifiers timestamps and handler metadata" do
    invalid_identifiers.each do |identifier|
      assert_generic_argument_error do
        EventLedger::PersistedEvent.new(**persisted_event_attributes.merge(event_id: identifier))
      end
    end

    [ nil, private_marker, 1, true ].each do |timestamp|
      assert_generic_argument_error do
        EventLedger::PersistedEvent.new(**persisted_event_attributes.merge(received_at: timestamp))
      end
    end

    %i[handler_name handler_version].each do |name|
      invalid_strings.each do |value|
        assert_generic_argument_error do
          EventLedger::PersistedEvent.new(**persisted_event_attributes.merge(name => value))
        end
      end
    end
  end

  test "persisted events require an Envelope rather than a hash or another public value" do
    receipt = EventLedger::Receipt.new(event_id: 12, shop_id: 7, duplicate: false)

    [ nil, envelope_attributes, receipt ].each do |envelope|
      assert_generic_argument_error do
        EventLedger::PersistedEvent.new(**persisted_event_attributes.merge(envelope: envelope))
      end
    end
  end

  test "effect results preserve supported outcomes and strict boolean duplicate flags" do
    [ :applied, :stale ].product([ true, false ]).each do |outcome, duplicate|
      result = EventLedger::EffectResult.new(effect_id: 23, outcome: outcome, duplicate: duplicate)

      assert_predicate result, :frozen?
      assert_same 23, result.effect_id
      assert_same outcome, result.outcome
      assert_same duplicate, result.duplicate
    end
  end

  test "effect results reject invalid identifiers unsupported outcomes and nonboolean flags" do
    invalid_identifiers.each do |identifier|
      assert_generic_argument_error do
        EventLedger::EffectResult.new(effect_id: identifier, outcome: :applied, duplicate: false)
      end
    end

    [ nil, :failed, "applied", "stale", private_marker, 1, true ].each do |outcome|
      assert_generic_argument_error do
        EventLedger::EffectResult.new(effect_id: 23, outcome: outcome, duplicate: false)
      end
    end

    [ nil, 0, 1, "false", private_marker, :true ].each do |duplicate|
      assert_generic_argument_error do
        EventLedger::EffectResult.new(effect_id: 23, outcome: :applied, duplicate: duplicate)
      end
    end
  end

  test "public value inspection and string conversion redact sensitive input" do
    values = [
      EventLedger::Envelope.new(**envelope_attributes),
      EventLedger::Receipt.new(event_id: 12, shop_id: 7, duplicate: false),
      EventLedger::PersistedEvent.new(**persisted_event_attributes),
      EventLedger::EffectResult.new(effect_id: 23, outcome: :applied, duplicate: false)
    ]

    values.each do |value|
      [ value.inspect, value.to_s ].each do |description|
        assert_includes description, "[REDACTED]"
        refute_includes description, private_marker
        refute_includes description, "synthetic item"
      end
    end
  end

  private

  def envelope_attributes
    {
      shop_id: 7,
      source: +"shopify",
      external_event_id: +"synthetic-event-12",
      topic: +"orders/create",
      subject_id: +"synthetic-order-42",
      occurred_at: Time.utc(2026, 9, 4, 12, 0, 0),
      source_version: +"opaque-v1",
      payload: {
        "items" => [ { "name" => +"synthetic item", "quantity" => 2 } ],
        "credentials" => { "token" => +private_marker }
      },
      payload_sha256: "a" * 64
    }
  end

  def persisted_event_attributes
    {
      event_id: 12,
      envelope: EventLedger::Envelope.new(**envelope_attributes),
      received_at: Time.utc(2026, 9, 4, 12, 0, 1),
      handler_name: +"orders.create",
      handler_version: +"v1"
    }
  end

  def invalid_identifiers
    [ nil, 0, -1, 1.5, private_marker, true, false ]
  end

  def invalid_strings
    [ nil, "", " \t\n", 1, :unsupported, true, false, [ private_marker ], { "token" => private_marker } ]
  end

  def private_marker
    "synthetic-contract-secret-do-not-print"
  end

  def assert_generic_argument_error(&block)
    error = assert_raises(ArgumentError, &block)
    refute_includes error.message, private_marker
    refute_includes error.message, "synthetic item"
    error
  end

  def assert_deeply_frozen_json(value)
    case value
    when Hash
      assert_predicate value, :frozen?
      value.each do |key, child|
        assert_predicate key, :frozen?
        assert_deeply_frozen_json child
      end
    when Array
      assert_predicate value, :frozen?
      value.each { |child| assert_deeply_frozen_json child }
    when String
      assert_predicate value, :frozen?
    end
  end
end
