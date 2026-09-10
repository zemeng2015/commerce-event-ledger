# frozen_string_literal: true

# Run through bin/rails runner against the isolated offline development stack.
abort "Demo requires the isolated development database" unless Rails.env.development? &&
  ActiveRecord::Base.connection.select_value("SELECT DATABASE()") == "commerce_event_ledger_development"

deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
loop do
  result = ActiveRecord::Base.connection.select_one(<<~SQL)
    SELECT e.status, e.deliveries_count,
      (SELECT COUNT(*) FROM processed_effects f WHERE f.event_id = e.id AND f.shop_id = e.shop_id) AS effects,
      (SELECT p.transition_count FROM order_projections p WHERE p.shop_id = e.shop_id AND p.source = e.source AND p.external_order_id = e.subject_id) AS transitions
    FROM received_events e
    WHERE e.shop_id = 7 AND e.source = 'shopify'
      AND e.external_event_id = 'orders/create:ed628f21-0845-4fa8-86a2-55e14f624ab2'
  SQL
  if result && result.fetch("status") == "processed" && result.fetch("deliveries_count") == 10 &&
    result.fetch("effects") == 1 && result.fetch("transitions") == 1
    puts JSON.generate(status: "processed", deliveries: 10, canonical_events: 1, effects: 1, transitions: 1)
    break
  end
  abort "Order-create demo did not reach one processed effect within 30 seconds" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
  sleep 0.25
end
