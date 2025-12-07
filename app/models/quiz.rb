class Quiz < ApplicationRecord
  belongs_to :ai_query
  belongs_to :grading_ai_query, class_name: 'AiQuery', optional: true
  belongs_to :journal
  has_many :quiz_answers, dependent: :destroy

  def full_journal
    self.quiz_answers.pluck(:user_response)
  end
end
