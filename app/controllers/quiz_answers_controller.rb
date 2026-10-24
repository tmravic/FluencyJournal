class QuizAnswersController < ApplicationController
  include JournalScoped
  before_action :set_quiz
  before_action :set_quiz_answer, only: [:show, :edit, :retry]

  def show
    @ai_output = @quiz_answer.ai_output
    @original_entry_text = original_entry_text_for(@ai_output)
  end

  def edit
    @quiz_entry = @quiz_answer.ai_output
  end

  def create
    @ai_output = @quiz.prepared_output(quiz_answer_params[:ai_output_id])
    @ai_query = @ai_output.ai_query
    @original_entry_text = original_entry_text_for(@ai_output)

    # A retry replaces the earlier answer to the same question. The lock
    # serialises two submissions for one quiz, and a failed save rolls the
    # deletion back so the old answer is kept.
    saved = false
    @quiz.with_lock do
      @quiz.quiz_answers.where(ai_output_id: @ai_output.id).destroy_all
      @quiz_answer = @quiz.quiz_answers.build(quiz_answer_params)
      saved = @quiz_answer.save
      raise ActiveRecord::Rollback unless saved
    end

    unless saved
      head :unprocessable_entity
      return
    end

    @show_grade_quiz_button = @quiz.fully_answered?
    respond_to do |format|
      format.turbo_stream
    end
  end

  def retry
    @quiz_entry = @quiz_answer.ai_output
    render :edit
  end

  private

  # The original journal text for a quiz question. A question's identifier
  # is its entry position, so read it from the saved output rather than
  # from a client-supplied param.
  def original_entry_text_for(question)
    @journal.entry_at(question.identifier)&.content
  end

  def set_quiz
    @quiz = @journal.quizzes.find(params[:quiz_id])
  end

  def set_quiz_answer
    @quiz_answer = @quiz.quiz_answers.find(params.expect(:id))
  end

  def quiz_answer_params
    params.expect(quiz_answer: [:user_response, :ai_output_id])
  end
end
