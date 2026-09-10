# frozen_string_literal: true

class AddProcessingClaims < ActiveRecord::Migration[8.1]
  def change
    add_column :received_events, :attempt_count, :integer, null: false, default: 0
    add_column :received_events, :claim_token, :string, limit: 64
    add_column :received_events, :claim_expires_at, :datetime, precision: 6
    add_column :received_events, :eligible_at, :datetime, precision: 6, null: false, default: -> { "CURRENT_TIMESTAMP(6)" }
    add_column :received_events, :completed_at, :datetime, precision: 6
    add_column :received_events, :last_error_code, :string, limit: 64
    add_index :received_events, [ :status, :eligible_at, :id ], name: "eligible_event_recovery"
    add_index :received_events, [ :status, :claim_expires_at ], name: "expired_claim_recovery"

    create_table :processing_attempts, charset: "utf8mb4", collation: "utf8mb4_0900_bin" do |t|
      t.bigint :event_id, null: false
      t.bigint :shop_id, null: false
      t.integer :number, null: false
      t.string :token, limit: 64, null: false
      t.string :status, limit: 32, null: false
      t.datetime :started_at, precision: 6, null: false
      t.datetime :finished_at, precision: 6
      t.string :error_code, limit: 64
    end
    add_index :processing_attempts, [ :event_id, :number ], unique: true
    add_index :processing_attempts, :token, unique: true
    add_foreign_key :processing_attempts, :received_events, column: [ :event_id, :shop_id ], primary_key: [ :id, :shop_id ]
  end
end
