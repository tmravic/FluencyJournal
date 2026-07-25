class QuizHint < ApplicationRecord
  belongs_to :quiz
  belongs_to :entry
  belongs_to :ai_query
end
