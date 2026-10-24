class QuizAnswer < ApplicationRecord
  belongs_to :quiz
  belongs_to :ai_output

  # One answer per question; the unique index enforces it for races.
  validates :ai_output_id, uniqueness: { scope: :quiz_id }
end
