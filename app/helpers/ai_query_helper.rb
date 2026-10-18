module AiQueryHelper
  def set_corrected_text_output(ai_query)
    ai_query.ai_outputs.corrected_text.first if ai_query
  end
end
