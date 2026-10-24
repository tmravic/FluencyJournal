class QuizAnswer < ApplicationRecord
  belongs_to :quiz
  belongs_to :ai_output

  # Checked only when the response changes, like the other length limits.
  MAX_RESPONSE_LENGTH = 5_000
  validates :user_response, length: { maximum: MAX_RESPONSE_LENGTH }, if: :will_save_change_to_user_response?

  # One answer per question; the unique index enforces it for races.
  validates :ai_output_id, uniqueness: { scope: :quiz_id }
end
