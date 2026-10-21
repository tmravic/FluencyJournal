class AiOutputsController < ApplicationController
  include SpeaksText
  include AccessibleOwner

  before_action :set_ai_output

  # GET /ai_outputs/:id/speak
  def speak
    speak_text(@ai_output.content)
  end

  def destroy
    @identifier = @ai_output.identifier
    @change_keyword = @ai_output.change_keyword
    @ai_output.destroy!
    @source_tag = params[:source_tag]

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
