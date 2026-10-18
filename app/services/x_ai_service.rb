class XAiService
  include SharedServiceMethods

  def initialize(attributes = {})
    @prompt = attributes[:prompt]
    @user = attributes[:user]
    @journal = attributes[:journal]
    @followup_origin = attributes[:followup_origin]
  end

  def call
    result = XAiChat.complete(
      model: @prompt.ai_model,
      instructions: @prompt.role_prompt(@user, @journal),
      user_messages: [@prompt.raw_prompt, @prompt.response_format(@user, @journal, nil)]
    )
    result.parsed_object
    ai_query = build_ai_query(result.raw_response, result.token_data, @prompt, @journal)

    create_ai_outputs_for_each_change(ai_query, @prompt, @user)
    create_ai_output_for_corrected_text(ai_query, @prompt, @user) unless @followup_origin
    ai_query
  end
end
