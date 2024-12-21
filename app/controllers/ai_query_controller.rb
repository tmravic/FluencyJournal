class AiQueryController < ApplicationController
  before_action :set_entry
  before_action :set_ai_query
  before_action :set_prompt

  def show
  end

  def destroy
    @ai_query.destroy!

    # respond_to do |format|
  end

  def set_ai_query
    @ai_query = AiQuery.find(params.expect(:id))
  end

  def set_entry
    @entry = current_group.entries.find(params[:entry_id])
  end

  def set_prompt
    @prompt = @ai_query.prompt
  end
end
