class AiOutputsController < ApplicationController
  before_action :set_ai_output

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
    @ai_output = AiOutput.find(params.expect(:id))
  end
end
