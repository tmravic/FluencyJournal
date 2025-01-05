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

ActiveRecord::Schema[8.0].define(version: 2025_01_04_221216) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_outputs", force: :cascade do |t|
    t.boolean "made_note"
    t.string "identifier"
    t.bigint "ai_query_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_query_id"], name: "index_ai_outputs_on_ai_query_id"
  end

  create_table "ai_queries", force: :cascade do |t|
    t.integer "prompt_tokens"
    t.integer "completion_tokens"
    t.integer "total_tokens"
    t.string "type"
    t.text "raw_response"
    t.integer "change_count"
    t.bigint "journal_id"
    t.bigint "prompt_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["journal_id"], name: "index_ai_queries_on_journal_id"
    t.index ["prompt_id"], name: "index_ai_queries_on_prompt_id"
  end

  create_table "entries", force: :cascade do |t|
    t.text "content"
    t.bigint "journal_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["journal_id"], name: "index_entries_on_journal_id"
  end

  create_table "entries_followups", id: false, force: :cascade do |t|
    t.bigint "entry_id", null: false
    t.bigint "followup_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_id", "followup_id"], name: "index_entries_followups_on_entry_id_and_followup_id", unique: true
    t.index ["entry_id"], name: "index_entries_followups_on_entry_id"
    t.index ["followup_id"], name: "index_entries_followups_on_followup_id"
  end

  create_table "followups", force: :cascade do |t|
    t.bigint "ai_queries_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_queries_id"], name: "index_followups_on_ai_queries_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "journals", force: :cascade do |t|
    t.string "title"
    t.bigint "user_id", null: false
    t.bigint "group_id", null: false
    t.decimal "last_interval", precision: 10, scale: 2, default: "1.0", null: false
    t.datetime "next_study_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_journals_on_group_id"
    t.index ["user_id"], name: "index_journals_on_user_id"
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "content"
    t.integer "category", default: 0, null: false
    t.decimal "last_interval", precision: 10, scale: 2, default: "1.0", null: false
    t.datetime "next_study_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "notes_followups", id: false, force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "followup_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["followup_id"], name: "index_notes_followups_on_followup_id"
    t.index ["note_id", "followup_id"], name: "index_notes_followups_on_note_id_and_followup_id", unique: true
    t.index ["note_id"], name: "index_notes_followups_on_note_id"
  end

  create_table "prompts", force: :cascade do |t|
    t.text "raw_prompt"
    t.text "sent_role_prompt"
    t.string "original_language_prompt"
    t.string "learning_language_prompt"
    t.string "type"
    t.string "ai_model"
    t.string "uuid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "original_language", null: false
    t.string "learning_language", null: false
    t.bigint "group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["group_id"], name: "index_users_on_group_id"
  end

  add_foreign_key "ai_outputs", "ai_queries"
  add_foreign_key "ai_queries", "journals"
  add_foreign_key "ai_queries", "prompts"
  add_foreign_key "entries", "journals"
  add_foreign_key "entries_followups", "entries"
  add_foreign_key "entries_followups", "followups"
  add_foreign_key "followups", "ai_queries", column: "ai_queries_id"
  add_foreign_key "journals", "groups"
  add_foreign_key "journals", "users"
  add_foreign_key "notes", "users"
  add_foreign_key "notes_followups", "followups"
  add_foreign_key "notes_followups", "notes"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "groups"
end
