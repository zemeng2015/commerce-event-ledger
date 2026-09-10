# frozen_string_literal: true

require "test_helper"

class HandlerRegistryTest < ActiveSupport::TestCase
  class TestOnlyNamedHandler
    attr_accessor :handler_name, :handler_version

    def initialize(handler_name: "order_projection", handler_version: "v1")
      @handler_name = handler_name.dup
      @handler_version = handler_version.dup
    end

    def call(event:)
      raise NotImplementedError, "This test double only supplies registry identity"
    end
  end

  test "route selection and exact persisted identity resolve the same immutable entry" do
    handler = TestOnlyNamedHandler.new
    entry = registry_entry(handler: handler)
    original = [ entry ]
    registry = EventLedger::HandlerRegistry.new(entries: original)
    original.clear
    handler.handler_name.replace("changed_name")
    handler.handler_version.replace("changed_version")

    assert_same entry, registry.select(source: "shopify", topic: "orders/create")
    assert_same entry, registry.fetch(handler_name: "order_projection", handler_version: "v1")
    assert registry.frozen?
    assert registry.entries.frozen?
    assert entry.frozen?
    assert entry.handler_name.frozen?
    assert entry.handler_version.frozen?
    assert_equal "order_projection", entry.handler_name
    assert_equal "v1", entry.handler_version
    assert_raises(FrozenError) { registry.entries.clear }
  end

  test "unknown handler versions and routes fail without a latest version fallback" do
    registry = EventLedger::HandlerRegistry.new(entries: [ registry_entry ])

    error = assert_raises(KeyError) do
      registry.fetch(handler_name: "order_projection", handler_version: "private-version-marker")
    end
    refute_includes error.message, "private-version-marker"
    assert_raises(KeyError) { registry.select(source: "shopify", topic: "orders/updated") }
    assert_raises(KeyError) { registry.select(source: "other_source", topic: "orders/create") }
  end

  test "duplicate routes and duplicate identities are rejected" do
    first = registry_entry
    same_route = registry_entry(handler: TestOnlyNamedHandler.new(handler_name: "another_handler"))
    same_identity = registry_entry(source: "another_source")

    assert_raises(ArgumentError) { EventLedger::HandlerRegistry.new(entries: [ first, same_route ]) }
    assert_raises(ArgumentError) { EventLedger::HandlerRegistry.new(entries: [ first, same_identity ]) }
  end

  test "registry rejects missing identities and malformed entries" do
    assert_raises(ArgumentError) { EventLedger::HandlerRegistry.new(entries: []) }
    assert_raises(ArgumentError) { EventLedger::HandlerRegistry.new(entries: [ Object.new ]) }
    assert_raises(ArgumentError) { registry_entry(handler: Object.new) }

    handler = TestOnlyNamedHandler.new
    handler.handler_name = nil
    assert_raises(ArgumentError) { registry_entry(handler: handler) }
    handler.handler_name = "order_projection"
    handler.handler_version = ""
    assert_raises(ArgumentError) { registry_entry(handler: handler) }
  end

  test "registry inspection never renders handler internals" do
    handler = TestOnlyNamedHandler.new(handler_name: "private-handler-marker")
    entry = registry_entry(handler: handler)
    registry = EventLedger::HandlerRegistry.new(entries: [ entry ])

    [ entry, registry ].each do |value|
      assert_includes value.inspect, "[REDACTED]"
      refute_includes value.inspect, "private-handler-marker"
      refute_includes value.to_s, "private-handler-marker"
    end
  end

  private

  def registry_entry(source: "shopify", topic: "orders/create", handler: TestOnlyNamedHandler.new)
    EventLedger::HandlerRegistry::Entry.new(source: source, topic: topic, handler: handler)
  end
end
