class AiQueriesController < ApplicationController
  before_action :set_journal
  before_action :set_ai_query, except: [ :ai_request ]
  before_action :set_prompt, except: [ :ai_request ]

  def show
    @source_tag = "ai_assistant"
    @corrected_text_output = @ai_query.find_ai_output_by_identifier("corrected_text")
  end

  def destroy
    @ai_models = get_ai_models
    @ai_query.destroy!
    @uuid = SecureRandom.uuid

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def ai_request
    original_language ="Original Language: #{entry_prompt_params[:base_content]}"
    learning_language ="Learning Language: #{entry_prompt_params[:user_generated_content]}"
    raw_prompt = original_language + "\n" + learning_language

    entry_prompt = EntryPrompt.build(
      raw_prompt: raw_prompt,
      ai_model: entry_prompt_params[:ai_model],
      uuid: entry_prompt_params[:uuid],
      base_content: entry_prompt_params[:base_content],
      user_generated_content: entry_prompt_params[:user_generated_content]
    )

    entry_prompt.sent_role_prompt = entry_prompt.role_prompt(@journal.user, @journal)

    if entry_prompt.save!
      AiRequestJob.perform_later(@journal, @api_key, entry_prompt)

      respond_to do |format|
        format.html { redirect_to journals_path, notice: t("ai_query.request_sent") }
        format.turbo_stream
      end
    end
  end

  def set_ai_query
    @ai_query = AiQuery.find(params.expect(:id))
  end

  def set_journal
    @journal = current_group.journals.find(params.require(:journal_id))
  end

  def set_prompt
    @prompt = @ai_query.prompt
  end

  def entry_prompt_params
    params.expect(
      entry_prompt: [ :base_content, :user_generated_content, :ai_model, :uuid, :journal_id ]
    )
  end
end
