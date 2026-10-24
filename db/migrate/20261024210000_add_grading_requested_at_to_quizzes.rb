class AddGradingRequestedAtToQuizzes < ActiveRecord::Migration[8.1]
  def change
    add_column :quizzes, :grading_requested_at, :datetime
  end
end
