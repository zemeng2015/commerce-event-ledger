# frozen_string_literal: true

class CreateCanonicalReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :shops, charset: "utf8mb4", collation: "utf8mb4_0900_bin" do |t|
      t.string :shop_domain, null: false
      t.timestamps
    end
    add_index :shops, :shop_domain, unique: true

    create_table :received_events, charset: "utf8mb4", collation: "utf8mb4_0900_bin" do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :source, limit: 32, null: false
      t.string :external_event_id, null: false
      t.string :topic, limit: 64, null: false
      t.string :subject_id, null: false
      t.json :normalized_payload, null: false
      t.string :payload_sha256, limit: 64, null: false
      # Source precision must survive MySQL's six-digit DATETIME precision.
      t.string :source_occurred_at, limit: 40, null: false
      t.json :source_version
      t.string :handler_name, limit: 64, null: false
      t.string :handler_version, limit: 64, null: false
      t.string :status, limit: 32, null: false, default: "pending"
      t.bigint :deliveries_count, null: false, default: 1
      t.datetime :last_received_at, null: false, precision: 6
      t.timestamps
    end
    add_index :received_events, [ :shop_id, :source, :external_event_id ], unique: true, name: "canonical_event_identity"
    add_index :received_events, [ :status, :created_at ], name: "pending_event_recovery"
  end
end
