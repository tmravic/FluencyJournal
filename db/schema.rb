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

ActiveRecord::Schema[8.0].define(version: 2024_12_14_003216) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_queries", force: :cascade do |t|
    t.integer "prompt_tokens"
    t.integer "completion_tokens"
    t.integer "total_tokens"
    t.string "type"
    t.text "raw_response"
    t.bigint "commit_id"
    t.bigint "followup_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commit_id"], name: "index_ai_queries_on_commit_id"
    t.index ["followup_id"], name: "index_ai_queries_on_followup_id"
  end

  create_table "commits", force: :cascade do |t|
    t.text "content"
    t.bigint "entry_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_id"], name: "index_commits_on_entry_id"
  end

  create_table "entries", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "group_id", null: false
    t.index ["group_id"], name: "index_entries_on_group_id"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "followups", force: :cascade do |t|
    t.bigint "commit_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commit_id"], name: "index_followups_on_commit_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "entry_id", null: false
    t.text "content"
    t.integer "category", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_id"], name: "index_notes_on_entry_id"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "prompts", force: :cascade do |t|
    t.bigint "ai_query_id"
    t.bigint "commit_id"
    t.bigint "followup_id"
    t.text "raw_prompt"
    t.string "type"
    t.string "ai_model"
    t.string "uuid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_query_id"], name: "index_prompts_on_ai_query_id"
    t.index ["commit_id"], name: "index_prompts_on_commit_id"
    t.index ["followup_id"], name: "index_prompts_on_followup_id"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "group_id", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["group_id"], name: "index_users_on_group_id"
  end

  add_foreign_key "ai_queries", "commits"
  add_foreign_key "ai_queries", "followups"
  add_foreign_key "commits", "entries"
  add_foreign_key "entries", "groups"
  add_foreign_key "entries", "users"
  add_foreign_key "followups", "commits"
  add_foreign_key "notes", "entries"
  add_foreign_key "notes", "users"
  add_foreign_key "prompts", "ai_queries"
  add_foreign_key "prompts", "commits"
  add_foreign_key "prompts", "followups"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "groups"
end
