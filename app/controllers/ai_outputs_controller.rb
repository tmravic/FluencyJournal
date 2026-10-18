class AiOutputsController < ApplicationController
  include AccessibleOwner

  before_action :set_ai_output

  # GET /ai_outputs/:id/speak
  def speak
    language = Prompt.language_code(Current.user.learning_language, default: "auto")

    audio = XAiTtsService.new(
      api_key: @api_key,
      text: @ai_output.content,
      language: language
    ).call

    send_data audio, type: "audio/mpeg", disposition: "inline"
  rescue XAiTtsService::TtsError
    head :service_unavailable
  end

  def destroy
    @identifier = @ai_output.identifier
    @change_keyword = @ai_output.ai_query.prompt.change_keyword
    @ai_output.destroy!
    @source_tag = params.dig(:source_tag)

    respond_to do |format|
      format.html { redirect_to journals_path, status: :see_other, notice: t("ai_output.change_deleted") }
      format.turbo_stream
    end
  end

  private

  def set_ai_output
    @ai_output = find_accessible_ai_output(params.expect(:id))
  end
end
