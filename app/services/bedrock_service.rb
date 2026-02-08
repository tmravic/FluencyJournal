class BedrockService
  include SharedServiceMethods

  def initialize(attributes = {})
    @entry_prompt = attributes[:entry_prompt]
    @user = attributes[:user]
    @journal = attributes[:journal]
  end

  def call
    response = make_call_to_elyza_llm
    json_response = parse_response_from_elyza_llm(response)
    token_data = organize_token_data(json_response)
    response_from_elyza_llm = json_response["generation"]
    @entry_prompt.update(ai_model: "elyza_llm")

    # SharedServiceMethods
    ai_query = build_ai_query(response_from_elyza_llm, token_data, @entry_prompt, @journal)
    create_ai_outputs_for_each_change(ai_query, @entry_prompt, @journal)
    create_ai_output_for_corrected_text(ai_query, @entry_prompt, @journal)

    ai_query
  end

  private

  def make_call_to_elyza_llm
    access_key = Rails.application.credentials.dig(:aws, :access_key_id)
    secret_access_key = Rails.application.credentials.dig(:aws, :secret_access_key)
    credentials = Aws::Credentials.new(access_key, secret_access_key)

    bedrock_client = Aws::BedrockRuntime::Client.new(
      region: "us-east-1",
      credentials: credentials
    )

    # "あなたは誠実で優秀な日本人のアシスタントです。特に指示が無い場合は 、常に日本語で回答してください。\n"
    input_text = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n" +
                 @entry_prompt.role_prompt(@user, @journal) + "\n" +
                 "<|eot_id|><|start_header_id|>user<|end_header_id|>\n" +
                 @entry_prompt.raw_prompt + "\n" +
                 "<|eot_id|><|start_header_id|>user<|end_header_id|>\n" +
                 @entry_prompt.response_format(@user) + "\n" +
                 "<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n"

    request_data = {
      "prompt" => input_text,
      "max_gen_len" => 5120,
      "temperature" => 0.0,
      "top_p" => 1.0
    }
    body = request_data.to_json
    response = bedrock_client.invoke_model(
      {
        accept: "application/json",
        content_type: "application/json",
        body: body,
        model_id: "arn:aws:bedrock:us-east-1:182181248970:imported-model/umdmug915ld0"
      }
    )

    response.body.rewind
    response
  end


  def organize_token_data(json_response)
    prompt_tokens = json_response["prompt_token_count"]
    completion_tokens = json_response["generation_token_count"]
    total_tokens = prompt_tokens + completion_tokens
    {"prompt_tokens"=>prompt_tokens, "completion_tokens"=>completion_tokens, "total_tokens"=>total_tokens}
  end

  def parse_response_from_elyza_llm(response)
    JSON.parse(response.body.read)
    # {"generation"=>
    #        "{ \n  change_1: { \n    content: \"昨日は → 機能は\", \n    explanation_en: \"訂正: 昨日はは日付を表す表現で、機能はは意味が通らないため、訂正した。\" \n  }, \n  change_2: { \n    content: \"\", \n    explanation_en: \" 追加: None\" \n  }, \n  corrected_text: \"機能は金曜日でした。\"",
    #      "prompt_token_count"=>454,
    #      "generation_token_count"=>101,
    #      "stop_reason"=>"stop",
    #      "logprobs"=>nil}
  end
end
