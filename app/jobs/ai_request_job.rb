class AiRequestJob < ApplicationJob
  queue_as :default

  def perform(journal, api_key, entry_prompt)
    user = journal.user

    connection = Faraday.new(url: "https://api.x.ai")
    response = connection.post do |req|
      req.url "/v1/chat/completions"
      req.options.timeout = 120
      req.options.open_timeout = 30
      req.headers["Content-Type"] = "application/json"
      req.headers["Authorization"] = "Bearer #{api_key}"
      req.body = {
        model: entry_prompt.ai_model,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: entry_prompt.role_prompt(user, journal)
          },
          {
            role: "user",
            content: entry_prompt.raw_prompt
          },
          {
            role: "user",
            content: entry_prompt.response_format(user)
          }
        ]
      }.to_json
    end

    json_response = JSON.parse(response.body)
    # {"id"=>"chatcmpl-Ac46SBbYGN9RVs1rflKYPNv6l1scE",
    #  "object"=>"chat.completion",
    #  "created"=>1733635600,
    #  "model"=>"gpt-4o-2024-08-06",
    #  "choices"=>
    #    [{"index"=>0,
    #      "message"=>
    #        {"role"=>"assistant",
    #         "content"=>
    #           "{\n  \"change_1\": {\n    \"content\": \"何年間のニキビ跡と太陽からの被害を治療したいです。→ 長年のニキビ跡や日焼けによる肌のダメージを改善したいです。\",\n    \"explanation_en\": \"The phrase '長年のニキビ跡や日焼けによる肌のダメージ' is more natural and concise to express 'years of acne scars and sun damage'. '改善したいです' is a more appropriate term to convey the intention to improve skin condition.\"\n  },\n  \"corrected_text\": \"今日はシルファームという肌の施術を受けます。小さい針とケミカルピーリングで長年のニキビ跡や日焼けによる肌のダメージを改善したいです。\"\n}",
    #         "refusal"=>nil},
    #      "logprobs"=>nil,
    #      "finish_reason"=>"stop"}],
    #  "usage"=>
    #    {"prompt_tokens"=>260,
    #     "completion_tokens"=>189,
    #     "total_tokens"=>449,
    #     "prompt_tokens_details"=>{"cached_tokens"=>0, "audio_tokens"=>0},
    #     "completion_tokens_details"=>
    #       {"reasoning_tokens"=>0,
    #        "audio_tokens"=>0,
    #        "accepted_prediction_tokens"=>0,
    #        "rejected_prediction_tokens"=>0}},
    #  "system_fingerprint"=>"fp_c7ca0ebaca"}

    full_token_details = json_response["usage"]
    # {
    #   "prompt_tokens"=>206,
    #   "completion_tokens"=>174,
    #   "total_tokens"=>380,
    #   "prompt_tokens_details"=> {
    #       "cached_tokens"=>0,
    #       "audio_tokens"=>0
    #     },
    #   "completion_tokens_details"=> {
    #     "reasoning_tokens"=>0,
    #     "audio_tokens"=>0,
    #     "accepted_prediction_tokens"=>0,
    #     "rejected_prediction_tokens"=>0
    #   }
    # }
    token_data = full_token_details.slice("prompt_tokens", "completion_tokens", "total_tokens")
    # {"prompt_tokens"=>211, "completion_tokens"=>130, "total_tokens"=>341}

    response_from_open_ai = json_response["choices"][0]["message"].dig("content")

    ai_query = AiQuery.build(
      prompt_tokens: token_data["prompt_tokens"],
      completion_tokens: token_data["completion_tokens"],
      total_tokens: token_data["total_tokens"],
      raw_response: response_from_open_ai
    )

    ai_query.prompt = entry_prompt
    ai_query.change_count = ai_query.count_changes(entry_prompt.change_keyword)
    ai_query.journal = journal
    ai_query.save!

    # Make an AiOutput for each change in the journal query
    (1..ai_query.change_count).each do |count|
      ai_query.ai_outputs.create(
        made_note: false,
        identifier: count.to_s
      ).tap do |ai_output|
        ai_output.content = ai_output.assemble_content(entry_prompt.change_keyword, journal.user)
        ai_output.save!
      end
    end
    # Make one more AiOutput for the Corrected Text
    ai_query.ai_outputs.create(
      made_note: false,
      identifier: "corrected_text"
    ).tap do |ai_output|
      ai_output.content = ai_output.assemble_content(entry_prompt.change_keyword, journal.user)
      ai_output.save!
    end

    source_tag = "ai_assistant"
    corrected_text = ai_query.corrected_text
    ai_query_id = ai_query.id

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{entry_prompt.uuid}",
      target: "ai_output",
      partial: "ai_queries/output",
      locals: { corrected_text:, ai_query_id:, source_tag:, user: }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{entry_prompt.uuid}",
      target: "previous_queries",
      partial: "journals/previous_queries",
      locals: { journal: }
    )
  end
end
