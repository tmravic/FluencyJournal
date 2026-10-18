class QuizAnswersController < ApplicationController
  before_action :set_journal
  before_action :set_quiz_answer, only: [:show, :edit, :retry]
  before_action :set_quiz

  def show
    #<ActionController::Parameters {"controller"=>"quiz_answers", "action"=>"show", "journal_id"=>"3", "quiz_id"=>"58", "id"=>"85"} permitted: false>
    @quiz_answer = QuizAnswer.find(params.dig(:id).to_i)
    @ai_output = @quiz_answer.ai_output
    @original_entry_text = get_original_language_from_journal(@ai_output.identifier)
  end

  def edit
    @quiz_entry = @quiz_answer.ai_output
  end

  def create
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

  def retry
    @quiz_entry = @quiz_answer.ai_output
    # #<ActionController::Parameters {"controller"=>"quiz_answers", "action"=>"retry", "journal_id"=>"3", "quiz_id"=>"60", "id"=>"604"} permitted: false>
    render :edit
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
    @journal.entry_at(identifier)&.content
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

  def set_quiz_answer
    @quiz_answer = QuizAnswer.find(params.expect(:id))
  end

  def quiz_answer_params
    params.expect(quiz_answer: [:user_response, :ai_output_id])
  end
end
