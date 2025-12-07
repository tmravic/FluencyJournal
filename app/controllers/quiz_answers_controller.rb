class QuizAnswersController < ApplicationController
  before_action :set_journal
  before_action :set_quiz

  def create
    # #<ActionController::Parameters {"quiz_answer"=>{"user_response"=>"test", "ai_output_id"=>"391", "identifier"=>"2"}, "controller"=>"quiz_answers", "action"=>"create", "journal_id"=>"5", "quiz_id"=>"72"} permitted: false>
    @ai_output = AiOutput.find(params.dig("quiz_answer", "ai_output_id"))
    @ai_query = @ai_output.ai_query
    @quiz_answer = @quiz.quiz_answers.build(quiz_answer_params)
    identifier = find_identifier
    @original_entry_text = get_original_language_from_journal(identifier)
    if @quiz_answer.save!
      mark_question_as_answered(identifier)
      @show_grade_quiz_button = true if all_questions_are_answered?
      respond_to do |format|
        format.turbo_stream
      end
    end
  end

  private

  def mark_question_as_answered(identifier)
    # pp session.to_h
    # "answered_quiz_questions"=>{"question_1"=>false, "question_2"=>false}
    session["answered_quiz_questions"]["question_#{identifier}"] = true
  end

  def all_questions_are_answered?
    session["answered_quiz_questions"].values.all?(true)
  end

  def get_original_language_from_journal(identifier)
    # @journal.full_journal
    # ["彼女のお母さんに会いました。", "３人で中目黒にピザを食べました。"]
    @journal.full_journal.slice(identifier.to_i - 1)
  end

  def find_identifier
    params.dig("quiz_answer", "identifier")
  end

  def set_journal
    @journal = current_group.journals.find(params[:journal_id])
  end

  def set_quiz
    @quiz = @journal.quizzes.find(params[:quiz_id])
  end

  def quiz_answer_params
    params.expect(quiz_answer: [:user_response, :ai_output_id])
  end
end
