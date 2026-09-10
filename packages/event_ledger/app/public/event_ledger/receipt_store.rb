# frozen_string_literal: true

require "time"

module EventLedger
  class ReceiptStore
    include Contract::Redacted

    class StorageError < StandardError; end
    class IdentityConflict < StandardError; end

    def initialize(shop_id:, shop_domain:)
      @shop_id = Contract.positive_id(shop_id)
      @shop_domain = Contract.text(shop_domain)
    end

    def receive(envelope:, handler_name:, handler_version:)
      raise ArgumentError unless envelope.instance_of?(Envelope) && envelope.shop_id == @shop_id
      name = Contract.text(handler_name)
      version = Contract.text(handler_version)
      raise ArgumentError unless name.bytesize <= 64 && version.bytesize <= 64

      retry_deadlocks { persist(envelope, name, version) }
    rescue IdentityConflict
      raise IdentityConflict, "Canonical event identity conflict", cause: nil
    rescue StandardError
      raise StorageError, "Webhook storage unavailable", cause: nil
    end

    private

    def persist(envelope, name, version)
      ReceivedEvent.connection_pool.with_connection do |connection|
        # A nested transaction would let callers acknowledge an uncommitted receipt.
        raise StorageError if connection.transaction_open?
        event_id = nil
        duplicate = false
        ReceivedEvent.transaction do
          shop = Shop.find_by(id: @shop_id) ||
            Shop.create_or_find_by!(id: @shop_id) { |record| record.shop_domain = @shop_domain }
          raise StorageError unless shop.shop_domain == @shop_domain
          attributes = canonical_attributes(envelope)
          record = ReceivedEvent.create_or_find_by!(shop_id: @shop_id, source: envelope.source,
            external_event_id: envelope.external_event_id) do |event|
            event.assign_attributes(attributes.merge(handler_name: name, handler_version: version,
              status: "pending", deliveries_count: 1, last_received_at: Time.now.utc))
          end
          duplicate = !record.previously_new_record?
          if duplicate
            record.lock!
            unless attributes.all? { |key, value| record.public_send(key) == value }
              raise IdentityConflict, "Canonical event identity conflict", cause: nil
            end
            record.update!(deliveries_count: record.deliveries_count + 1, last_received_at: Time.now.utc)
          end
          event_id = record.id
        end
        Receipt.new(event_id: event_id, shop_id: @shop_id, duplicate: duplicate)
      end
    end

    def retry_deadlocks
      attempts = 0
      begin
        yield
      rescue ActiveRecord::Deadlocked
        attempts += 1
        raise if attempts >= 5
        # MySQL has rolled back the whole transaction. Retry from a new
        # transaction; never resume a statement in the aborted savepoint.
        sleep(0.005 * attempts)
        retry
      end
    end

    def canonical_attributes(envelope)
      { topic: envelope.topic, subject_id: envelope.subject_id,
        normalized_payload: envelope.payload, payload_sha256: envelope.payload_sha256,
        source_occurred_at: envelope.occurred_at.iso8601(9), source_version: envelope.source_version }
    end
  end
end
