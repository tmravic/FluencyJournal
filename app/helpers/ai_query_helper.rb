module AiQueryHelper
  def set_ai_query_when_job_finishes(ai_query_id)
    AiQuery.find(ai_query_id) if ai_query_id.present? && ai_query_id != t("ai_query.processing")
  end

  def set_corrected_text_output(ai_query)
    ai_query.find_ai_output_by_identifier("corrected_text") if ai_query
  end
end
