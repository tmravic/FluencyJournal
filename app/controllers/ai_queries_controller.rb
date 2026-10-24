class AiQueriesController < ApplicationController
  include JournalScoped
  before_action :set_ai_query, except: [ :ai_request ]
  before_action :set_prompt, except: [ :ai_request ]

  def show
    @source_tag = SourceTag::AI_ASSISTANT
    @corrected_text_output = @ai_query.find_ai_output_by_identifier("corrected_text")
  end

  def destroy
    @deleting_a_quiz = @ai_query.quiz_related?
    @ai_query.destroy!

    respond_to do |format|
      format.html { redirect_to journal_path(@journal), status: :see_other }
      format.turbo_stream
    end
  end

  def ai_request
    raw_prompt = create_raw_prompt

    entry_prompt = EntryPrompt.build(
      raw_prompt: raw_prompt,
      ai_model: entry_prompt_params[:ai_model],
      uuid: entry_prompt_params[:uuid],
      base_content: entry_prompt_params[:base_content],
      user_generated_content: entry_prompt_params[:user_generated_content]
    )

    entry_prompt.sent_role_prompt = entry_prompt.role_prompt(@journal.user, @journal)

    unless entry_prompt.save
      head :unprocessable_entity
      return
    end

    AiRequestJob.perform_later(@journal, entry_prompt)

    respond_to do |format|
      format.html { redirect_to journals_path, status: :see_other, notice: t("ai_query.request_sent") }
      format.turbo_stream
    end
  end

  private

  def set_ai_query
    @ai_query = @journal.ai_queries.find(params.expect(:id))
  end

  def set_prompt
    @prompt = @ai_query.prompt
  end

  def entry_prompt_params
    params.expect(
      entry_prompt: [ :base_content, :user_generated_content, :ai_model, :uuid ]
    )
  end

  def create_raw_prompt
    original_language ="Original Language: #{entry_prompt_params[:base_content]}"
    learning_language ="Learning Language: #{entry_prompt_params[:user_generated_content]}"
    original_language + "\n" + learning_language
  end
end
