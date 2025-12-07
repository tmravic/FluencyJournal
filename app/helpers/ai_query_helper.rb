module AiQueryHelper
  def set_corrected_text_output(ai_query)
    ai_query.find_ai_output_by_identifier("corrected_text") if ai_query
  end
end
