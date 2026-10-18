class Quiz < ApplicationRecord
  belongs_to :ai_query, inverse_of: :quizzes
  belongs_to :grading_ai_query, class_name: "AiQuery", optional: true, inverse_of: :graded_quizzes
  belongs_to :journal
  has_many :quiz_answers, dependent: :destroy
  has_many :quiz_hints, -> { order(:entry_id) }, dependent: :destroy

  # Student answers in entry-position order. Journal#full_journal is the entry text.
  def responses
    quiz_answers
      .joins(:ai_output)
      .order(Arel.sql("CAST(ai_outputs.identifier AS INTEGER)"))
      .pluck("quiz_answers.user_response")
  end
end
