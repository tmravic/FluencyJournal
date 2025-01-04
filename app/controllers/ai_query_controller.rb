class AiQueryController < ApplicationController
  before_action :set_journal
  before_action :set_ai_query
  before_action :set_prompt

  def show
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

  def set_ai_query
    @ai_query = AiQuery.find(params.expect(:id))
  end

  def set_journal
    @journal = current_group.journals.find(params.require(:journal_id))
  end

  def set_prompt
    @prompt = @ai_query.prompt
  end
end
