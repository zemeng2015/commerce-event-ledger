# frozen_string_literal: true

require "securerandom"
require "time"

module EventLedger
  class ProcessingStore
    include Contract::Redacted
    class ProcessingError < StandardError; end
    MAX_ATTEMPTS = 5
    LEASE_SECONDS = 300

    def initialize(shop_id:)
      @shop_id = Contract.positive_id(shop_id)
    end

    def self.eligible_event_ids(limit: 100)
      raise ArgumentError unless limit.is_a?(Integer) && limit.between?(1, 100)
      now = Time.now.utc
      ReceivedEvent.where("(status IN ('pending', 'retry_wait') AND eligible_at <= ?) OR (status = 'processing' AND claim_expires_at <= ?)", now, now)
        .order(:eligible_at, :id).limit(limit).pluck(:shop_id, :id)
    rescue StandardError
      raise ProcessingError, "Event processing unavailable", cause: nil
    end

    def claim(event_id:)
      id = Contract.positive_id(event_id)
      transaction do
        record = ReceivedEvent.lock.find_by(id: id, shop_id: @shop_id)
        now = Time.now.utc
        next nil unless record && eligible?(record, now)
        if record.status == "processing"
          ProcessingAttempt.where(event_id: id, shop_id: @shop_id, token: record.claim_token)
            .update_all(status: "abandoned", finished_at: now, error_code: "lease_expired")
        end
        if record.attempt_count >= MAX_ATTEMPTS
          record.update!(status: "dead_letter", claim_token: nil, claim_expires_at: nil, last_error_code: "attempts_exhausted")
          next nil
        end
        token = SecureRandom.hex(32)
        number = record.attempt_count + 1
        record.update!(status: "processing", claim_token: token, claim_expires_at: now + LEASE_SECONDS, attempt_count: number)
        ProcessingAttempt.create!(event_id: id, shop_id: @shop_id, number: number, token: token, status: "processing", started_at: now)
        Claim.new(event: persisted(record), token: token, attempt_number: number)
      end
    rescue StandardError
      raise ProcessingError, "Event processing unavailable", cause: nil
    end

    def finish(claim:)
      acknowledge(claim, success: true)
    end

    def fail(claim:)
      acknowledge(claim, success: false)
    end

    private

    def transaction
      Record.connection_pool.with_connection do |connection|
        raise ProcessingError if connection.transaction_open?
        Record.transaction { yield }
      end
    end

    def eligible?(record, now)
      case record.status
      when "pending", "retry_wait"
        record.eligible_at <= now
      when "processing"
        record.claim_expires_at && record.claim_expires_at <= now
      else
        false
      end
    end

    def acknowledge(claim, success:)
      raise ArgumentError unless claim.instance_of?(Claim) && claim.event.envelope.shop_id == @shop_id
      transaction do
        record = ReceivedEvent.lock.find_by(id: claim.event.event_id, shop_id: @shop_id)
        next false unless record && record.status == "processing" && record.claim_token == claim.token
        now = Time.now.utc
        status = success ? "processed" : (record.attempt_count >= MAX_ATTEMPTS ? "dead_letter" : "retry_wait")
        error = success ? nil : "handler_failed"
        record.update!(status: status, claim_token: nil, claim_expires_at: nil,
          completed_at: success ? now : nil, eligible_at: now + [ 2**record.attempt_count, 30 ].min, last_error_code: error)
        ProcessingAttempt.where(event_id: record.id, shop_id: @shop_id, token: claim.token)
          .update_all(status: success ? "succeeded" : status, finished_at: now, error_code: error)
        true
      end
    rescue StandardError
      raise ProcessingError, "Event processing unavailable", cause: nil
    end

    def persisted(record)
      envelope = Envelope.new(shop_id: record.shop_id, source: record.source, external_event_id: record.external_event_id,
        topic: record.topic, subject_id: record.subject_id, occurred_at: Time.iso8601(record.source_occurred_at),
        source_version: record.source_version, payload: record.normalized_payload, payload_sha256: record.payload_sha256)
      PersistedEvent.new(event_id: record.id, envelope: envelope, received_at: record.created_at,
        handler_name: record.handler_name, handler_version: record.handler_version)
    end
  end
end
