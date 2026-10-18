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

ActiveRecord::Schema[8.1].define(version: 2026_10_18_220000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_outputs", force: :cascade do |t|
    t.boolean "made_note"
    t.string "identifier"
    t.text "content"
    t.bigint "ai_query_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "line", null: false
    t.index ["ai_query_id"], name: "index_ai_outputs_on_ai_query_id"
  end

  create_table "ai_queries", force: :cascade do |t|
    t.integer "prompt_tokens"
    t.integer "completion_tokens"
    t.integer "total_tokens"
    t.text "raw_response"
    t.integer "change_count"
    t.bigint "journal_id"
    t.bigint "prompt_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["journal_id"], name: "index_ai_queries_on_journal_id"
    t.index ["prompt_id"], name: "index_ai_queries_on_prompt_id", unique: true
  end

  create_table "entries", force: :cascade do |t|
    t.text "content"
    t.bigint "journal_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position", null: false
    t.index ["journal_id", "position"], name: "index_entries_on_journal_id_and_position", unique: true
    t.index ["journal_id"], name: "index_entries_on_journal_id"
  end

  create_table "followup_template_prompts", force: :cascade do |t|
    t.string "base_content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_followup_template_prompts_on_user_id"
  end

  create_table "followups", force: :cascade do |t|
    t.string "origin_type"
    t.bigint "origin_id"
    t.string "source_tag"
    t.bigint "prompt_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["origin_type", "origin_id"], name: "index_followups_on_origin"
    t.index ["prompt_id"], name: "index_followups_on_prompt_id", unique: true
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "journal_followups", force: :cascade do |t|
    t.bigint "journal_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["journal_id"], name: "index_journal_followups_on_journal_id"
  end

  create_table "journals", force: :cascade do |t|
    t.string "title"
    t.bigint "user_id", null: false
    t.bigint "group_id", null: false
    t.decimal "last_interval", precision: 10, scale: 2, default: "1.0", null: false
    t.datetime "next_study_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_studied_at"
    t.decimal "easiness_factor", precision: 4, scale: 2, default: "2.5", null: false
    t.integer "repetitions", default: 0, null: false
    t.index ["group_id"], name: "index_journals_on_group_id"
    t.index ["last_studied_at"], name: "index_journals_on_last_studied_at"
    t.index ["user_id"], name: "index_journals_on_user_id"
  end

  create_table "journals_notes", id: false, force: :cascade do |t|
    t.bigint "journal_id", null: false
    t.bigint "note_id", null: false
    t.index ["journal_id", "note_id"], name: "index_journals_notes_on_journal_id_and_note_id", unique: true
    t.index ["journal_id"], name: "index_journals_notes_on_journal_id"
    t.index ["note_id"], name: "index_journals_notes_on_note_id"
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "content"
    t.integer "category", default: 0, null: false
    t.decimal "last_interval", precision: 10, scale: 2, default: "1.0", null: false
    t.datetime "next_study_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "meaning"
    t.text "extras"
    t.decimal "easiness_factor", precision: 4, scale: 2, default: "2.5", null: false
    t.integer "repetitions", default: 0, null: false
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "prompts", force: :cascade do |t|
    t.text "raw_prompt"
    t.text "sent_role_prompt"
    t.string "base_content"
    t.string "user_generated_content"
    t.string "ai_model"
    t.string "uuid"
    t.string "type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "followup_template_prompt_id"
    t.index ["followup_template_prompt_id"], name: "index_prompts_on_followup_template_prompt_id"
  end

  create_table "quiz_answers", force: :cascade do |t|
    t.text "user_response"
    t.text "feedback"
    t.bigint "quiz_id", null: false
    t.bigint "ai_output_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_output_id"], name: "index_quiz_answers_on_ai_output_id"
    t.index ["quiz_id"], name: "index_quiz_answers_on_quiz_id"
  end

  create_table "quiz_hints", force: :cascade do |t|
    t.string "hint_content", null: false
    t.bigint "quiz_id", null: false
    t.bigint "entry_id", null: false
    t.bigint "ai_query_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_query_id"], name: "index_quiz_hints_on_ai_query_id"
    t.index ["entry_id"], name: "index_quiz_hints_on_entry_id"
    t.index ["quiz_id"], name: "index_quiz_hints_on_quiz_id"
  end

  create_table "quizzes", force: :cascade do |t|
    t.text "feedback"
    t.bigint "journal_id", null: false
    t.bigint "ai_query_id", null: false
    t.bigint "grading_ai_query_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_query_id"], name: "index_quizzes_on_ai_query_id"
    t.index ["grading_ai_query_id"], name: "index_quizzes_on_grading_ai_query_id"
    t.index ["journal_id"], name: "index_quizzes_on_journal_id"
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
  add_foreign_key "followup_template_prompts", "users"
  add_foreign_key "followups", "prompts"
  add_foreign_key "journal_followups", "journals"
  add_foreign_key "journals", "groups"
  add_foreign_key "journals", "users"
  add_foreign_key "notes", "users"
  add_foreign_key "prompts", "followup_template_prompts"
  add_foreign_key "quiz_answers", "ai_outputs"
  add_foreign_key "quiz_answers", "quizzes"
  add_foreign_key "quiz_hints", "ai_queries"
  add_foreign_key "quiz_hints", "entries"
  add_foreign_key "quiz_hints", "quizzes"
  add_foreign_key "quizzes", "ai_queries"
  add_foreign_key "quizzes", "ai_queries", column: "grading_ai_query_id"
  add_foreign_key "quizzes", "journals"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "groups"
end
