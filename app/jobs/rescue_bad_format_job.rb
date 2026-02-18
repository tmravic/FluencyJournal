class RescueBadFormatJob < ApplicationJob
  queue_as :default

  def perform(api_key, ai_query)
    bad_response = ai_query.raw_response

    connection = Faraday.new("https://api.x.ai") do |conn|
      conn.request :json
      conn.response :json
      conn.adapter Faraday.default_adapter
    end

    payload = {
      model: "grok-4-1-fast-non-reasoning",
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: "You are a JSON formatting assistant. Output only valid JSON, no extra text." },
        { role: "user", content: "Fix this invalid string to valid JSON:\n#{bad_response}" }
      ]
    }

    response = connection.post("/v1/chat/completions") do |req|
      req.headers["Authorization"] = "Bearer #{api_key}"
      req.body = payload.to_json
    end

    if response.success?
      if response.body.kind_of?(Hash)
        cleaned_response = response.body["choices"][0]["message"]["content"]
        begin
          if JSON.parse(cleaned_response)
            ai_query.update(raw_response: cleaned_response)
          end
        rescue JSON::ParserError => e
          Rails.logger.warn(
            "Failed to parse Grok fixed JSON", ai_query_id: ai_query.id, raw_content: cleaned_response, error: e.message
          )
        rescue => e
          Rails.logger.error("Unexpected error in RescueBadFormatJob", error: e, ai_query_id: ai_query.id)
        end
        return cleaned_response
      end
    else
      raise "API error #{response.status}: #{response.body}"
    end
  end
end
