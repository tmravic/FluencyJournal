class QuizzesController < ApplicationController
  before_action :set_journal
  before_action :set_quiz, only: [:grade_quiz, :show]

  def prepare_quiz
    uuid = SecureRandom.uuid
    prepare_quiz_prompt = PrepareQuizPrompt.build(
      raw_prompt: @journal.full_journal,
      ai_model: "grok-4-fast-non-reasoning",
      uuid: uuid,
      base_content: @journal.full_journal.join,
      user_generated_content: @journal.full_journal.join
    )

    prepare_quiz_prompt.sent_role_prompt = prepare_quiz_prompt.role_prompt(@journal.user)

    if prepare_quiz_prompt.save!
      PrepareQuizJob.perform_later(@journal, @api_key, prepare_quiz_prompt)
      @uuid = prepare_quiz_prompt.uuid

      @ai_query_id = I18n.t("quiz.preparing")
      set_answered_status_in_session

      respond_to do |format|
        format.html { render :prepare_quiz, notice: @ai_query_id }
        format.turbo_stream
      end
    end
  end

  def peek
    @quiz_entry_frame = "ai_output_#{params.dig(:ai_output)}"
    @journal = Journal.find(params.dig(:journal_id))
    @quiz = Quiz.find(params.dig(:quiz_id))
    @ai_output = AiOutput.find(params.dig(:ai_output))
    @identifier = @ai_output.identifier
    @entry_content = @journal.full_journal.slice(@identifier.to_i - 1)
    @entry = @journal.entries.order(:id).offset(@identifier.to_i - 1).first

    respond_to do |format|
      format.turbo_stream
    end
  end

  def unpeek
    @frame = params.dig(:frame) # "ai_output_1119"
    @ai_output = AiOutput.find(@frame.split("_").last)
    @journal = @ai_output.journal
    @quiz = Quiz.find(params.dig(:quiz_id))

    respond_to do |format|
      format.turbo_stream
    end
  end

  def grade_quiz
    uuid = SecureRandom.uuid
    original_journal = @journal.full_journal
    # ["彼女のお母さんに会いました。", "３人で中目黒にピザを食べました。"]
    quiz_entries = get_translated_journal_entries
    # ["I met her mother.", "The three of us ate pizza in Nakameguro."]
    user_translation = @quiz.full_journal
    # ["Test", "Test"]

    prompt_content = "Original journal entries: #{original_journal}, " +
                     "Quiz questions: #{quiz_entries}," + "Quiz Answers: #{user_translation}"

    quiz_result_prompt = QuizResultPrompt.build(
      raw_prompt: prompt_content,
      ai_model: "grok-4-fast-non-reasoning",
      uuid: uuid,
      base_content: combine_original_and_translation(original_journal, quiz_entries),
      user_generated_content: user_translation.join
    )
    quiz_result_prompt.sent_role_prompt = quiz_result_prompt.role_prompt(@journal.user)

    if quiz_result_prompt.save
      @uuid = quiz_result_prompt.uuid
      GradeQuizJob.perform_later(@journal, @api_key, quiz_result_prompt, @quiz)
      respond_to do |format|
        format.turbo_stream
      end
    end
  end

  def show
    @source_tag = "ai_assistant"
    # #<ActionController::Parameters {"controller"=>"quizzes", "action"=>"show", "journal_id"=>"5", "id"=>"147"}
    @ai_query = @quiz.ai_query
    @ai_outputs = @ai_query.ai_outputs
    @user = @journal.user
    @grading_ai_query = @quiz.grading_ai_query
    @assessment_output = @grading_ai_query.find_ai_output_by_identifier("assessment")
    @prompt = @grading_ai_query.prompt
  end

  def reset_quiz
    @source_tag = 'ai_assistant'
    @entries = @journal.entries.order(:id)
    destroy_all_unfinished_quizzes!

    respond_to do |format|
      format.turbo_stream
    end
  end

  def close_quiz
    @source_tag = 'ai_assistant'
    @entries = @journal.entries.order(:id)

    respond_to do |format|
      format.turbo_stream
    end
  end

  def show_original_language
    @quiz_entry = AiOutput.find(params.dig(:quiz_entry))
    @quiz = Quiz.find(params.dig(:quiz))

    respond_to do |format|
      format.turbo_stream
    end
  end

  def hide_original_language
    @quiz_entry = AiOutput.find(params.dig(:quiz_entry))
    @quiz = Quiz.find(params.dig(:quiz))

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def destroy_all_unfinished_quizzes!
    @journal.quizzes.where(grading_ai_query_id: nil).destroy_all
  end

  def set_journal
    @journal = current_group.journals.find(params[:journal_id])
  end

  def set_quiz
    @quiz = @journal.quizzes.find(params[:id])
  end

  def combine_original_and_translation(original_journal, quiz_entries)
    (original_journal + quiz_entries).join(', ')
  end

  def get_translated_journal_entries
    @quiz.ai_query.ai_outputs.pluck(:content)
  end

  def set_quiz_id_in_session
    session[:quiz_id] = @quiz.id
  end

  def set_answered_status_in_session
    session[:answered_quiz_questions] = {}
    @journal.full_journal.each_with_index do |_, index|
      index += 1
      session[:answered_quiz_questions]["question_#{index}"] = false
    end
    # session.to_h
    # ...
    # "answered_quiz_questions"=>{"question_1"=>false, "question_2"=>false}
  end
end
