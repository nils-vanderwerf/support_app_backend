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

ActiveRecord::Schema[7.1].define(version: 2024_06_25_121635) do
  create_table "appointments", force: :cascade do |t|
    t.datetime "date"
    t.integer "duration"
    t.string "location"
    t.integer "user_id"
    t.integer "client_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "clients", force: :cascade do |t|
    t.string "name"
    t.integer "age"
    t.string "gender"
    t.string "address"
    t.string "phone"
    t.text "health_conditions"
    t.text "medication"
    t.text "allergies"
    t.string "emergency_contact_name"
    t.string "emergency_contact_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "specializations", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "support_worker_id"
  end

  create_table "specializations_support_workers", id: false, force: :cascade do |t|
    t.integer "support_worker_id", null: false
    t.integer "specialization_id", null: false
  end

  create_table "support_workers", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.integer "age"
    t.text "bio"
    t.text "experience"
    t.string "phone"
    t.string "email"
    t.string "availability"
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

end
