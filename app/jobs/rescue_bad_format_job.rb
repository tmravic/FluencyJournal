class RescueBadFormatJob < ApplicationJob
  queue_as :default

  def perform(ai_query)
    bad_response = ai_query.raw_response
    result = XAiChat.complete(
      model: "grok-4-1-fast-non-reasoning",
      instructions: "You are a JSON formatting assistant. Output only valid JSON, no extra text.",
      user_messages: ["Fix this invalid string to valid JSON:\n#{bad_response}"]
    )
    cleaned_response = result.raw_response

    begin
      if result.parsed || JSON.parse(cleaned_response)
        ai_query.update(raw_response: cleaned_response)
      end
    rescue JSON::ParserError => e
      Rails.logger.warn(
        "Failed to parse Grok fixed JSON", ai_query_id: ai_query.id, raw_content: cleaned_response, error: e.message
      )
    rescue => e
      Rails.logger.error("Unexpected error in RescueBadFormatJob", error: e, ai_query_id: ai_query.id)
    end
    cleaned_response
  end
end
