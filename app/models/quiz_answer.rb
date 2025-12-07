class QuizAnswer < ApplicationRecord
  belongs_to :quiz
  belongs_to :ai_output
end
