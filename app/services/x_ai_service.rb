class XAiService
  include SharedServiceMethods

  def initialize(api_key, entry_prompt, user, journal)
    @api_key = api_key
    @entry_prompt = entry_prompt
    @user = user
    @journal = journal
  end

  def call
    response = make_call_to_x_api
    json_response = parse_response_from_x_api(response)
    token_data = organize_token_data(json_response)
    response_from_x_ai = json_response["choices"][0]["message"].dig("content")
    ai_query = build_ai_query(response_from_x_ai, token_data, @entry_prompt, @journal) # SharedServiceMethods
    create_ai_outputs_for_each_change(ai_query, @entry_prompt, @journal) # SharedServiceMethods
    create_ai_output_for_corrected_text(ai_query, @entry_prompt, @journal) # SharedServiceMethods
  end

  private

  def organize_token_data(json_response)
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
    full_token_details.slice("prompt_tokens", "completion_tokens", "total_tokens")
    # {"prompt_tokens"=>211, "completion_tokens"=>130, "total_tokens"=>341}
  end

  def parse_response_from_x_api(response)
    JSON.parse(response.body)
    # {"id"=>"chatcmpl-Ac46SBbYGN9RVs1rflKYPNv6l1scE",
    #  "object"=>"chat.completion",
    #  "created"=>1733635600,
    #  "model"=>"gpt-4o-2024-08-06",
    #  "choices"=>
    #    [{"index"=>0,
    #      "message"=>
    #        {"role"=>"assistant",
    #         "content"=>
    #           "{\n  \"change_1\": {\n    \"content\": \"何年間のニキビ跡と太陽からの被害を治療したいです。→ 長年のニキビ跡や日焼け
    # による肌のダメージを改善したいです。\",\n    \"explanation_en\": \"The phrase '長年のニキビ跡や日焼けによる肌のダメージ' is more
    # natural and concise to express 'years of acne scars and sun damage'. '改善したいです' is a more appropriate term to
    # convey the intention to improve skin condition.\"\n  },\n  \"corrected_text\": \"今日はシルファームという肌の施術を受けます。
    # 小さい針とケミカルピーリングで長年のニキビ跡や日焼けによる肌のダメージを改善したいです。\"\n}",
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
  end

  def make_call_to_x_api
    connection = Faraday.new(url: "https://api.x.ai")
    connection.post do |request|
      request.url "/v1/chat/completions"
      request.options.timeout = 120
      request.options.open_timeout = 60
      request.headers["Content-Type"] = "application/json"
      request.headers["Authorization"] = "Bearer #{@api_key}"
      request.body = {
        model: @entry_prompt.ai_model,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: @entry_prompt.role_prompt(@user, @journal)
          },
          {
            role: "user",
            content: @entry_prompt.raw_prompt
          },
          {
            role: "user",
            content: @entry_prompt.response_format(@user)
          }
        ]
      }.to_json
    end
  end
end
