# frozen_string_literal: true

require "time"

module Orders
  class EffectExecutor
    class ExecutionError < StandardError; end

    def call(event:)
      unless event.instance_of?(EventLedger::PersistedEvent) &&
        event.handler_name == Handler::NAME && event.handler_version == Handler::VERSION &&
        event.envelope.source == Handler::SOURCE && event.envelope.topic == Handler::TOPIC &&
        event.envelope.payload["order_id"] == event.envelope.subject_id && event.envelope.payload["state"] == "created"
        raise ArgumentError
      end

      attempts = 0
      begin
        commit_effect(event)
      rescue ActiveRecord::Deadlocked
        attempts += 1
        raise if attempts >= 5
        sleep(0.005 * attempts)
        retry
      end
    rescue StandardError
      raise ExecutionError, "Order effect execution failed", cause: nil
    end

    def inspect
      "#<Orders::EffectExecutor [REDACTED]>"
    end
    alias_method :to_s, :inspect

    def as_json(_options = nil)
      { "type" => self.class.name, "redacted" => true }
    end

    private

    def commit_effect(event)
      envelope = event.envelope
      result = nil
      Record.connection_pool.with_connection do |connection|
        raise ExecutionError if connection.transaction_open?
        Record.transaction do
          identity = { shop_id: envelope.shop_id, source: envelope.source, external_order_id: envelope.subject_id }
          projection = OrderProjection.find_by(identity) || OrderProjection.create_or_find_by!(identity) do |row|
            row.state = "created"
            row.transition_count = 0
          end
          projection.lock!
          effect_key = { event_id: event.event_id, handler_name: event.handler_name, handler_version: event.handler_version }
          effect = ProcessedEffect.lock.find_by(effect_key)
          if effect
            unless effect.shop_id == envelope.shop_id && effect.order_projection_id == projection.id
              raise ExecutionError
            end
            result = EventLedger::EffectResult.new(effect_id: effect.id, outcome: effect.outcome.to_sym, duplicate: true)
          else
            # Equal source timestamps never use arrival order as a tie-breaker.
            stale = projection.source_occurred_at && envelope.occurred_at <= Time.iso8601(projection.source_occurred_at)
            outcome = stale ? "stale" : "applied"
            unless stale
              projection.update!(source_occurred_at: envelope.occurred_at.iso8601(9),
                last_event_id: event.event_id, transition_count: projection.transition_count + 1)
            end
            effect = ProcessedEffect.create!(effect_key.merge(shop_id: envelope.shop_id,
              order_projection_id: projection.id, outcome: outcome))
            result = EventLedger::EffectResult.new(effect_id: effect.id, outcome: outcome.to_sym, duplicate: false)
          end
        end
      end
      result
    end
  end
end
