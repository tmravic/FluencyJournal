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
      user_messages: [@prompt.raw_prompt, @prompt.response_format(@user)]
    )
    ai_query = build_ai_query(result.raw_response, result.token_data, @prompt, @journal)

    if @followup_origin
      followup = @prompt.followup
      # If this is a followup on a Note it won't be connected to any journal.
      save_followup_based_on_origin(ai_query, followup, @followup_origin)
    end

    create_ai_outputs_for_each_change(ai_query, @prompt, @user)
    create_ai_output_for_corrected_text(ai_query, @prompt, @user) unless @followup_origin
    ai_query
  end
end
