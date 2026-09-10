# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_10_000001) do
  create_table "received_events", charset: "utf8mb4", collation: "utf8mb4_0900_bin", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deliveries_count", default: 1, null: false
    t.string "external_event_id", null: false
    t.string "handler_name", limit: 64, null: false
    t.string "handler_version", limit: 64, null: false
    t.datetime "last_received_at", null: false
    t.json "normalized_payload", null: false
    t.string "payload_sha256", limit: 64, null: false
    t.bigint "shop_id", null: false
    t.string "source", limit: 32, null: false
    t.string "source_occurred_at", limit: 40, null: false
    t.json "source_version"
    t.string "status", limit: 32, default: "pending", null: false
    t.string "subject_id", null: false
    t.string "topic", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "source", "external_event_id"], name: "canonical_event_identity", unique: true
    t.index ["shop_id"], name: "index_received_events_on_shop_id"
    t.index ["status", "created_at"], name: "pending_event_recovery"
  end

  create_table "shops", charset: "utf8mb4", collation: "utf8mb4_0900_bin", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "shop_domain", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_domain"], name: "index_shops_on_shop_domain", unique: true
  end

  add_foreign_key "received_events", "shops"
end
