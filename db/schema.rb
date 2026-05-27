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

ActiveRecord::Schema[7.1].define(version: 2026_05_27_011349) do
  create_table "admin_messages", force: :cascade do |t|
    t.integer "support_worker_id"
    t.string "sender"
    t.text "content"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "appointments", force: :cascade do |t|
    t.datetime "date"
    t.integer "duration"
    t.string "location"
    t.integer "user_id"
    t.integer "client_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "support_worker_id"
    t.datetime "deleted_at"
    t.string "status", default: "approved", null: false
    t.integer "conversation_id"
    t.string "initiated_by", default: "client"
  end

  create_table "clients", force: :cascade do |t|
    t.string "first_name"
    t.string "gender"
    t.string "phone"
    t.text "health_conditions"
    t.text "medication"
    t.text "allergies"
    t.string "emergency_contact_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "last_name"
    t.string "middle_name"
    t.text "bio"
    t.string "location"
    t.string "email"
    t.string "emergency_contact_first_name"
    t.string "emergency_contact_last_name"
    t.date "date_of_birth"
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.integer "client_id"
    t.integer "support_worker_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "messages", force: :cascade do |t|
    t.integer "conversation_id"
    t.string "sender_type"
    t.integer "sender_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "specialisations", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "support_worker_id"
  end

  create_table "specialisations_support_workers", id: false, force: :cascade do |t|
    t.integer "support_worker_id", null: false
    t.integer "specialisation_id", null: false
  end

  create_table "support_workers", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.text "bio"
    t.string "phone"
    t.string "email"
    t.string "availability"
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "middle_name"
    t.string "emergency_contact_first_name"
    t.string "emergency_contact_last_name"
    t.string "emergency_contact_phone"
    t.string "gender"
    t.string "status", default: "pending", null: false
    t.string "police_check_number"
    t.string "wwcc_number"
    t.text "check_notes"
    t.string "agent_recommendation"
    t.integer "approved_by_id"
    t.date "date_of_birth"
    t.integer "experience"
    t.string "qualification"
    t.string "institution"
    t.string "field_of_study"
    t.date "police_check_expiry"
    t.date "wwcc_expiry"
    t.text "admin_note"
    t.datetime "rejected_at"
    t.string "state"
    t.index ["user_id"], name: "index_support_workers_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role"
    t.json "tokens"
    t.string "first_name"
    t.string "last_name"
    t.string "middle_name"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "visit_reports", force: :cascade do |t|
    t.integer "user_id"
    t.integer "client_id"
    t.integer "appointment_id"
    t.datetime "date"
    t.text "activities"
    t.text "observations"
    t.text "follow_up_actions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "clients", "users"
  add_foreign_key "support_workers", "users"
end
