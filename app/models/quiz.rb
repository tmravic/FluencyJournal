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

  # Every output of the preparing query. The member actions and the
  # grading prompt use all of them, not only the line questions.
  def prepared_outputs
    ai_query.ai_outputs
  end

  def prepared_output(id)
    prepared_outputs.find(id)
  end

  # Question texts in the order the outputs were saved (line order). An
  # unordered pluck lets PostgreSQL return rows in any order, which
  # misaligns them with #responses in the grading prompt.
  def prepared_texts
    prepared_outputs.order(:id).pluck(:content)
  end

  # The grader's feedback, or none before grading.
  def feedback_outputs
    grading_ai_query&.ai_outputs || AiOutput.none
  end

  def assessment_output
    feedback_outputs.assessment.first
  end

  def grading_prompt
    grading_ai_query&.prompt
  end

  # The hint for the entry +output+ asks about, or nil.
  def hint_for(output)
    quiz_hints.find_by(entry: journal.entry_at(output.line_number))
  end

  # True once every question has at least one saved answer.
  def fully_answered?
    question_ids = questions.ids
    return false if question_ids.empty?

    quiz_answers.where(ai_output_id: question_ids).distinct.count(:ai_output_id) == question_ids.size
  end

  # Student answers in entry-position order. Journal#entry_texts is the entry text.
  def responses
    quiz_answers
      .joins(:ai_output)
      .order(Arel.sql("CAST(ai_outputs.identifier AS INTEGER)"))
      .pluck("quiz_answers.user_response")
  end
end
