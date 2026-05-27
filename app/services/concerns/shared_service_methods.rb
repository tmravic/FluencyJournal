module SharedServiceMethods
  def make_call_to_x_api(api_key, prompt, user, journal)
    connection = Faraday.new(url: "https://api.x.ai")
    connection.post do |request|
      request.url "/v1/chat/completions"
      request.options.timeout = 120
      request.options.open_timeout = 60
      request.headers["Content-Type"] = "application/json"
      request.headers["Authorization"] = "Bearer #{api_key}"
      request.body = {
        model: prompt.ai_model,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: prompt.role_prompt(user, journal)
          },
          {
            role: "user",
            content: prompt.raw_prompt
          },
          {
            role: "user",
            content: prompt.response_format(user)
          }
        ]
      }.to_json
    end
  end

  def save_followup_based_on_origin(ai_query, followup, followup_origin)
    ai_query.followups.push(followup)
    if ai_query.save!
      if followup_origin.is_a?(Entry)
        followup_origin.followups.push(followup)
      elsif followup_origin.is_a?(AiOutput)
        followup_origin.followups.push(followup)
      elsif followup_origin.is_a?(Note)
        followup_origin.followups.push(followup)
      elsif followup_origin.is_a?(JournalFollowup)
        followup_origin.followups.push(followup)
      end
    end
  end

  def organize_token_data(json_response)
    full_token_details = json_response["usage"]
    # {
    #   "prompt_tokens"=>206, "completion_tokens"=>174, "total_tokens"=>380,
    #   "prompt_tokens_details"=> { "cached_tokens"=>0, "audio_tokens"=>0 },
    #   "completion_tokens_details"=> {
    #     "reasoning_tokens"=>0, "audio_tokens"=>0,
    #     "accepted_prediction_tokens"=>0, "rejected_prediction_tokens"=>0
    #   }
    # }
    full_token_details.slice("prompt_tokens", "completion_tokens", "total_tokens")
    # {"prompt_tokens"=>211, "completion_tokens"=>130, "total_tokens"=>341}
  end

  def build_ai_query(response_from_model, token_data, prompt, journal)
    ai_query = AiQuery.build(
      prompt_tokens: token_data["prompt_tokens"],
      completion_tokens: token_data["completion_tokens"],
      total_tokens: token_data["total_tokens"],
      raw_response: response_from_model
    )

    ai_query.change_count = ai_query.count_changes(prompt.change_keyword)
    ai_query.prompt = prompt
    ai_query.journal = journal if journal
    ai_query.save!
    ai_query
  end

  def create_ai_outputs_for_each_change(ai_query, prompt, user)
    (1..ai_query.change_count).each do |count|
      ai_query.ai_outputs.create(
        made_note: false,
        identifier: count.to_s
      ).tap do |ai_output|
        ai_output.content = ai_output.assemble_content(prompt.change_keyword, user)
        ai_output.save!
      end
    end
  end

  def create_ai_output_for_corrected_text(ai_query, prompt, user)
    ai_query.ai_outputs.create(
      made_note: false,
      identifier: "corrected_text"
    ).tap do |ai_output|
      ai_output.content = ai_output.assemble_content(prompt.change_keyword, user)
      ai_output.save!
    end
  end
end
