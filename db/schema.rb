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

ActiveRecord::Schema[8.1].define(version: 2026_09_10_000005) do
  create_table "order_projections", charset: "utf8mb4", collation: "utf8mb4_0900_bin", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_order_id", null: false
    t.bigint "last_event_id"
    t.bigint "shop_id", null: false
    t.string "source", limit: 32, null: false
    t.string "source_occurred_at", limit: 40
    t.string "state", limit: 32, null: false
    t.bigint "transition_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["id", "shop_id"], name: "order_projection_tenant_identity", unique: true
    t.index ["last_event_id", "shop_id"], name: "fk_rails_56cecf6462"
    t.index ["shop_id", "source", "external_order_id"], name: "order_projection_identity", unique: true
    t.index ["shop_id"], name: "index_order_projections_on_shop_id"
  end

  create_table "processed_effects", charset: "utf8mb4", collation: "utf8mb4_0900_bin", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.string "handler_name", limit: 64, null: false
    t.string "handler_version", limit: 64, null: false
    t.bigint "order_projection_id", null: false
    t.string "outcome", limit: 16, null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "handler_name", "handler_version"], name: "handler_effect_identity", unique: true
    t.index ["event_id", "shop_id"], name: "fk_rails_dde9dfc1ac"
    t.index ["order_projection_id", "shop_id"], name: "fk_rails_cd465e5205"
  end

  create_table "processing_attempts", charset: "utf8mb4", collation: "utf8mb4_0900_bin", force: :cascade do |t|
    t.string "error_code", limit: 64
    t.bigint "event_id", null: false
    t.datetime "finished_at"
    t.integer "number", null: false
    t.bigint "shop_id", null: false
    t.datetime "started_at", null: false
    t.string "status", limit: 32, null: false
    t.string "token_digest", limit: 64, null: false
    t.index ["event_id", "number"], name: "index_processing_attempts_on_event_id_and_number", unique: true
    t.index ["event_id", "shop_id"], name: "fk_rails_7dd43bed32"
    t.index ["token_digest"], name: "index_processing_attempts_on_token_digest", unique: true
  end

  create_table "received_events", charset: "utf8mb4", collation: "utf8mb4_0900_bin", force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.datetime "claim_expires_at"
    t.string "claim_token_digest", limit: 64
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "deliveries_count", default: 1, null: false
    t.datetime "eligible_at", default: -> { "CURRENT_TIMESTAMP(6)" }, null: false
    t.string "external_event_id", null: false
    t.string "handler_name", limit: 64, null: false
    t.string "handler_version", limit: 64, null: false
    t.string "last_error_code", limit: 64
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
    t.index ["id", "shop_id"], name: "received_event_tenant_identity", unique: true
    t.index ["shop_id", "source", "external_event_id"], name: "canonical_event_identity", unique: true
    t.index ["shop_id"], name: "index_received_events_on_shop_id"
    t.index ["status", "claim_expires_at"], name: "expired_claim_recovery"
    t.index ["status", "created_at"], name: "pending_event_recovery"
    t.index ["status", "eligible_at", "id"], name: "eligible_event_recovery"
  end

  create_table "shops", charset: "utf8mb4", collation: "utf8mb4_0900_bin", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "shop_domain", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_domain"], name: "index_shops_on_shop_domain", unique: true
  end

  create_table "solid_queue_batch_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  add_foreign_key "order_projections", "received_events", column: ["last_event_id", "shop_id"], primary_key: ["id", "shop_id"]
  add_foreign_key "order_projections", "shops"
  add_foreign_key "processed_effects", "order_projections", column: ["order_projection_id", "shop_id"], primary_key: ["id", "shop_id"]
  add_foreign_key "processed_effects", "received_events", column: ["event_id", "shop_id"], primary_key: ["id", "shop_id"]
  add_foreign_key "processing_attempts", "received_events", column: ["event_id", "shop_id"], primary_key: ["id", "shop_id"]
  add_foreign_key "received_events", "shops"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
