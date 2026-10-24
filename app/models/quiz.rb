class Quiz < ApplicationRecord
  belongs_to :ai_query, inverse_of: :quizzes
  belongs_to :grading_ai_query, class_name: "AiQuery", optional: true, inverse_of: :graded_quizzes
  belongs_to :journal
  has_many :quiz_answers, dependent: :destroy
  has_many :quiz_hints, -> { order(:entry_id) }, dependent: :destroy

  # Questions are the line outputs of the query that prepared the quiz.
  def questions
    ai_query.ai_outputs.line
  end

  # True once every question has at least one saved answer.
  def fully_answered?
    question_ids = questions.ids
    return false if question_ids.empty?

    quiz_answers.where(ai_output_id: question_ids).distinct.count(:ai_output_id) == question_ids.size
  end

  # Student answers in entry-position order. Journal#full_journal is the entry text.
  def responses
    quiz_answers
      .joins(:ai_output)
      .order(Arel.sql("CAST(ai_outputs.identifier AS INTEGER)"))
      .pluck("quiz_answers.user_response")
  end
end
