class DropQuizTables < ActiveRecord::Migration[8.1]
  # Answers and hints reference quizzes, so those tables go first.
  # The block is only used if this migration is rolled back.
  def change
    drop_table :quiz_answers do |t|
      t.text :user_response
      t.text :feedback
      t.references :quiz, null: false, foreign_key: true
      t.references :ai_output, null: false, foreign_key: true
      t.timestamps
      t.index [ :quiz_id, :ai_output_id ],
              unique: true,
              name: "index_quiz_answers_on_quiz_id_and_ai_output_id"
    end

    drop_table :quiz_hints do |t|
      t.string :hint_content, null: false
      t.references :quiz, null: false, foreign_key: true
      t.references :entry, null: false, foreign_key: true
      t.references :ai_query, null: false, foreign_key: true
      t.timestamps
    end

    drop_table :quizzes do |t|
      t.text :feedback
      t.references :journal, null: false, foreign_key: true
      t.references :ai_query, null: false, foreign_key: true
      t.references :grading_ai_query, foreign_key: { to_table: :ai_queries }
      t.datetime :grading_requested_at
      t.timestamps
    end
  end
end
