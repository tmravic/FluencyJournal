class AddGradingAiQueryIdToQuizzes < ActiveRecord::Migration[8.0]
  def change
    add_column :quizzes, :grading_ai_query_id, :integer
    add_foreign_key :quizzes, :ai_queries, column: :grading_ai_query_id
  end
end
