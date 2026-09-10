# frozen_string_literal: true

class CreateOrderEffects < ActiveRecord::Migration[8.1]
  def change
    add_index :received_events, [ :id, :shop_id ], unique: true, name: "received_event_tenant_identity"

    create_table :order_projections, charset: "utf8mb4", collation: "utf8mb4_0900_bin" do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :source, limit: 32, null: false
      t.string :external_order_id, null: false
      t.string :state, limit: 32, null: false
      t.string :source_occurred_at, limit: 40
      t.bigint :last_event_id
      t.bigint :transition_count, null: false, default: 0
      t.timestamps
    end
    add_index :order_projections, [ :shop_id, :source, :external_order_id ], unique: true, name: "order_projection_identity"
    add_index :order_projections, [ :id, :shop_id ], unique: true, name: "order_projection_tenant_identity"
    add_foreign_key :order_projections, :received_events, column: [ :last_event_id, :shop_id ], primary_key: [ :id, :shop_id ]

    create_table :processed_effects, charset: "utf8mb4", collation: "utf8mb4_0900_bin" do |t|
      t.bigint :event_id, null: false
      t.bigint :shop_id, null: false
      t.bigint :order_projection_id, null: false
      t.string :handler_name, limit: 64, null: false
      t.string :handler_version, limit: 64, null: false
      t.string :outcome, limit: 16, null: false
      t.timestamps
    end
    add_index :processed_effects, [ :event_id, :handler_name, :handler_version ], unique: true, name: "handler_effect_identity"
    add_foreign_key :processed_effects, :received_events, column: [ :event_id, :shop_id ], primary_key: [ :id, :shop_id ]
    add_foreign_key :processed_effects, :order_projections, column: [ :order_projection_id, :shop_id ], primary_key: [ :id, :shop_id ]
  end
end
