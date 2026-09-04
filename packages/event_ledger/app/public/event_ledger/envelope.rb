# frozen_string_literal: true

module EventLedger
  # Typed normalization output, not evidence of authentication or persistence.
  # payload_sha256 identifies the exact authenticated raw request bytes.
  class Envelope
    include Contract::Redacted

    attr_reader :shop_id, :source, :external_event_id, :topic, :subject_id,
      :occurred_at, :source_version, :payload, :payload_sha256

    def initialize(shop_id:, source:, external_event_id:, topic:, subject_id:, occurred_at:,
      payload:, payload_sha256:, source_version: nil)
      @shop_id = Contract.positive_id(shop_id)
      @source = Contract.text(source)
      @external_event_id = Contract.text(external_event_id)
      @topic = Contract.text(topic)
      @subject_id = Contract.text(subject_id)
      @occurred_at = Contract.timestamp(occurred_at)
      @source_version = Contract.version(source_version)
      @payload = Contract.json_object(payload)
      @payload_sha256 = Contract.digest(payload_sha256)
      freeze
    end
  end
end
