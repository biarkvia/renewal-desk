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

ActiveRecord::Schema[8.1].define(version: 2026_11_16_210300) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "contract_events", force: :cascade do |t|
    t.bigint "contract_id", null: false
    t.bigint "actor_id", null: false
    t.string "event_type", null: false
    t.jsonb "payload", null: false
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_contract_events_on_actor_id"
    t.index ["contract_id", "id"], name: "index_contract_events_on_contract_id_and_id"
    t.check_constraint "event_type::text = ANY (ARRAY['contract_created'::character varying, 'contract_updated'::character varying, 'decision_recorded'::character varying]::text[])", name: "contract_events_type"
    t.check_constraint "jsonb_typeof(payload) = 'object'::text", name: "contract_events_payload"
  end

  create_table "contracts", force: :cascade do |t|
    t.bigint "owner_id", null: false
    t.string "title", limit: 160, null: false
    t.string "counterparty", limit: 160, null: false
    t.date "ends_on", null: false
    t.integer "notice_days", null: false
    t.date "notice_due_on", null: false
    t.integer "schedule_revision", default: 1, null: false
    t.string "decision"
    t.datetime "decided_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notice_due_on", "id"], name: "index_contracts_on_open_notice_due_on", where: "(decision IS NULL)"
    t.index ["owner_id", "notice_due_on", "id"], name: "index_contracts_on_owner_id_and_notice_due_on_and_id"
    t.check_constraint "decision IS NULL AND decided_at IS NULL OR decision IS NOT NULL AND (decision::text = ANY (ARRAY['renew'::character varying, 'do_not_renew'::character varying]::text[])) AND decided_at IS NOT NULL", name: "contracts_decision_state"
    t.check_constraint "lock_version >= 0", name: "contracts_lock_version"
    t.check_constraint "notice_days >= 0 AND notice_days <= 365", name: "contracts_notice_period"
    t.check_constraint "notice_due_on = (ends_on - notice_days) AND notice_due_on >= '0001-01-01'::date AND ends_on <= '9999-12-31'::date", name: "contracts_notice_due_on"
    t.check_constraint "schedule_revision > 0", name: "contracts_schedule_revision"
  end

  create_table "reminders", force: :cascade do |t|
    t.bigint "contract_id", null: false
    t.integer "schedule_revision", null: false
    t.datetime "created_at", null: false
    t.index ["contract_id", "schedule_revision"], name: "index_reminders_on_contract_id_and_schedule_revision", unique: true
    t.check_constraint "schedule_revision > 0", name: "reminders_schedule_revision"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "contract_events", "contracts"
  add_foreign_key "contract_events", "users", column: "actor_id"
  add_foreign_key "contracts", "users", column: "owner_id"
  add_foreign_key "reminders", "contracts"
  add_foreign_key "sessions", "users"
end
