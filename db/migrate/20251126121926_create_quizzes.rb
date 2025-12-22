class CreateQuizzes < ActiveRecord::Migration[8.0]
  def change
    create_table :quizzes do |t|
      t.text :feedback
      t.references :journal, null: false, foreign_key: true
      t.references :ai_query, null: false, foreign_key: true
      t.references :grading_ai_query, foreign_key: { to_table: :ai_queries }
      t.timestamps
    end
  end
end