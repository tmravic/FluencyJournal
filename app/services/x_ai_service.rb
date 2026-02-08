class XAiService
  include SharedServiceMethods

  def initialize(attributes = {})
    @api_key = attributes[:api_key]
    @prompt = attributes[:prompt]
    @user = attributes[:user]
    @journal = attributes[:journal]
    @followup_origin = attributes[:followup_origin]
  end

  def call
    response = make_call_to_x_api(@api_key, @prompt, @user, @journal)
    json_response = parse_response_from_x_api(response)
    token_data = organize_token_data(json_response)
    response_from_x_ai = json_response["choices"][0]["message"].dig("content")
    ai_query = build_ai_query(response_from_x_ai, token_data, @prompt, @journal)

    if @followup_origin
      followup = @prompt.followup
      # If this is a followup on a Note it won't be connected to any journal.
      save_followup_based_on_origin(ai_query, followup, @followup_origin)
    end

    create_ai_outputs_for_each_change(ai_query, @prompt, @user)
    create_ai_output_for_corrected_text(ai_query, @prompt, @user) unless @followup_origin
    ai_query
  end

  private

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
    #  "usage"=> {"prompt_tokens"=>260, "completion_tokens"=>189, "total_tokens"=>449, "prompt_tokens_details"=>
    #      {
    #        "cached_tokens"=>0, "audio_tokens"=>0}, "completion_tokens_details"=> {
    #      "reasoning_tokens"=>0, "audio_tokens"=>0, "accepted_prediction_tokens"=>0, "rejected_prediction_tokens"=>0
    #    }
    #  },
    #  "system_fingerprint"=>"fp_c7ca0ebaca"
    # }
  end
end
