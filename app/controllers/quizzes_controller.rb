class QuizzesController < ApplicationController
  include JournalScoped
  before_action :set_quiz, only: %i[
    grade_quiz show destroy peek unpeek
    show_original_language hide_original_language show_hint hide_hint
  ]
  before_action :set_quiz_output, only: %i[
    peek unpeek show_original_language hide_original_language show_hint hide_hint
  ]

  def prepare_quiz
    uuid = SecureRandom.uuid
    prepare_quiz_prompt = PrepareQuizPrompt.build(
      raw_prompt: JSON.generate(@journal.full_journal),
      ai_model: "grok-4-fast-non-reasoning",
      uuid: uuid,
      base_content: @journal.full_journal.join,
      user_generated_content: @journal.full_journal.join
    )

    prepare_quiz_prompt.sent_role_prompt = prepare_quiz_prompt.role_prompt(@journal.user, @journal)

    unless prepare_quiz_prompt.save
      head :unprocessable_entity
      return
    end

    PrepareQuizJob.perform_later(@journal, prepare_quiz_prompt)
    @uuid = prepare_quiz_prompt.uuid

    @ai_query_id = I18n.t("quiz.preparing")

    respond_to do |format|
      format.html { redirect_to journal_path(@journal), status: :see_other, notice: t("quiz.preparing") }
      format.turbo_stream
    end
  end

  def peek
    @quiz_entry_frame = helpers.dom_id(@ai_output)
    @identifier = @ai_output.identifier
    @entry = @journal.entry_at(@ai_output.line_number)
    @entry_content = @entry&.content

    respond_to do |format|
      format.turbo_stream
    end
  end

  def unpeek
    @frame = helpers.dom_id(@ai_output)

    respond_to do |format|
      format.turbo_stream
    end
  end

  def grade_quiz
    uuid = SecureRandom.uuid
    original_journal = @journal.full_journal
    # ["彼女のお母さんに会いました。", "３人で中目黒にピザを食べました。"]
    quiz_entries = @quiz.prepared_texts
    # ["I met her mother.", "The three of us ate pizza in Nakameguro."]
    user_translation = @quiz.responses
    # ["Test", "Test"]

    prompt_content = [
      "Original journal entries: #{JSON.generate(original_journal)}",
      "Quiz questions: #{JSON.generate(quiz_entries)}",
      "Quiz Answers: #{JSON.generate(user_translation)}"
    ].join("\n")

    quiz_result_prompt = QuizResultPrompt.build(
      raw_prompt: prompt_content,
      ai_model: "grok-4-fast-non-reasoning",
      uuid: uuid,
      base_content: combine_original_and_translation(original_journal, quiz_entries),
      user_generated_content: user_translation.join
    )
    quiz_result_prompt.sent_role_prompt = quiz_result_prompt.role_prompt(@journal.user, @journal)

    if quiz_result_prompt.save
      @uuid = quiz_result_prompt.uuid
      GradeQuizJob.perform_later(@journal, quiz_result_prompt, @quiz)
      respond_to do |format|
        format.turbo_stream
      end
    else
      head :unprocessable_entity
    end
  end

  def show
    @source_tag = SourceTag::AI_ASSISTANT
    # The question query owns the quiz. The grading query holds the feedback.
    @ai_query = @quiz.ai_query
    @grading_ai_query = @quiz.grading_ai_query
    @user = @journal.user
    @ai_outputs = @quiz.feedback_outputs
    @assessment_output = @quiz.assessment_output
    @prompt = @quiz.grading_prompt
  end

  def reset_quiz
    @source_tag = SourceTag::AI_ASSISTANT
    @entries = @journal.entries.ordered
    destroy_all_unfinished_quizzes!

    respond_to do |format|
      format.turbo_stream
    end
  end

  def close_quiz
    @source_tag = SourceTag::AI_ASSISTANT
    @entries = @journal.entries.ordered

    respond_to do |format|
      format.turbo_stream
    end
  end

  def destroy
    @source_tag = SourceTag::AI_ASSISTANT
    @entries = @journal.entries.ordered
    queries = [ @quiz.ai_query, @quiz.grading_ai_query ].compact.uniq
    @quiz.destroy!
    queries.each(&:destroy!)

    respond_to do |format|
      format.html { redirect_to journal_path(@journal), status: :see_other, notice: t("quiz.deleted") }
      format.turbo_stream { render "close_quiz" }
    end
  end

  def show_original_language
    respond_to do |format|
      format.turbo_stream
    end
  end

  def hide_original_language
    respond_to do |format|
      format.turbo_stream
    end
  end

  def show_hint
    quiz_hint = @quiz.hint_for(@quiz_entry)

    unless quiz_hint
      head :unprocessable_entity
      return
    end

    @hint_content = quiz_hint.hint_content

    respond_to do |format|
      format.turbo_stream
    end
  end

  def hide_hint
    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def destroy_all_unfinished_quizzes!
    @journal.quizzes.where(grading_ai_query_id: nil).destroy_all
  end

  def set_quiz
    @quiz = @journal.quizzes.find(params[:id])
  end

  def set_quiz_output
    @ai_output = @quiz.prepared_output(params[:ai_output_id])
    @quiz_entry = @ai_output
  end

  def combine_original_and_translation(original_journal, quiz_entries)
    (original_journal + quiz_entries).join(', ')
  end
end
