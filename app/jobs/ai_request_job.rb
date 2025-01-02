class AiRequestJob < ApplicationJob
  queue_as :default

  def perform(ai_request_params, api_key)
    # params
    # ai_request_params["prompt"]
    # ai_request_params["ai_model"]
    # ai_request_params["uuid"]

    # { "prompt"=>"Original Language: This year to save me from tears I'll give it to someone special.\nLearning Language: ", ... }

    journal = Journal.find(ai_request_params['journal_id'])
    user = journal.user

    # make a new EntryPrompt using the ai_request_params as raw_content
    entry_prompt = EntryPrompt.create(
      raw_prompt: ai_request_params["prompt"],
      ai_model: ai_request_params["ai_model"],
      uuid: ai_request_params["uuid"]
    )

    connection = Faraday.new(url: 'https://api.openai.com')
    response = connection.post do |req|
      req.url "/v1/chat/completions"
      req.options.timeout = 120
      req.options.open_timeout = 30
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = "Bearer #{api_key}"
      req.body = {
        model: entry_prompt.ai_model,
        response_format: { type: "json_object" },
        messages: [
          {
            role: 'system',
            content: entry_prompt.system_prompt(user)
          },
          {
            role: 'user',
            content: ai_request_params[:prompt]
          },
          {
            role: 'user',
            content: entry_prompt.response_format(user)
          }
        ],
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

    full_token_details = json_response['usage']
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

    response_from_open_ai = json_response['choices'][0]['message'].dig("content")

    # Use this to create a JournalQuery
    journal_query = JournalQuery.build(
      prompt_tokens: token_data["prompt_tokens"],
      completion_tokens: token_data["completion_tokens"],
      total_tokens: token_data["total_tokens"],
      raw_response: response_from_open_ai
    )

    journal_query.prompt = entry_prompt
    journal_query.journal = journal
    journal_query.save!

    generated_idea = journal_query.corrected_text
    change_list = journal_query.id

    uuid = ai_request_params[:uuid]
    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{uuid}",
      target: 'ai_output',
      partial: 'ai/output',
      locals: { generated_idea:, change_list: }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{uuid}",
      target: 'previous_queries',
      partial: 'journals/previous_queries',
      locals: { journal: }
    )
  end
end
