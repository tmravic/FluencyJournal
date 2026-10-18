class XAiChat
  Result = Data.define(
    :raw_response,
    :parsed,
    :prompt_tokens,
    :completion_tokens,
    :total_tokens
  ) do
    def token_data
      {
        "prompt_tokens" => prompt_tokens,
        "completion_tokens" => completion_tokens,
        "total_tokens" => total_tokens
      }
    end
  end

  def self.complete(model:, instructions:, user_messages:)
    from_message(build(model:, instructions:, user_messages:).complete)
  end

  # xAI's default protocol in ruby_llm is Responses. This app posts to
  # chat/completions. The gem's alias table also rewrites several stored Grok
  # ids (grok-4-fast-non-reasoning, grok-4-1-fast-non-reasoning) to grok-4.3,
  # so the model id on the payload is the one the prompt stored.
  def self.build(model:, instructions:, user_messages:)
    chat = RubyLLM.chat(
      model: model,
      provider: :xai,
      protocol: :chat_completions,
      assume_model_exists: true
    )
    chat.with_instructions(instructions)
    chat.with_provider_options(
      model: model,
      response_format: { type: "json_object" }
    )
    Array(user_messages).each do |text|
      chat.add_message(role: :user, content: text)
    end
    chat
  end

  def self.from_message(message)
    parsed = parsed_hash(message)
    prompt_tokens = message.tokens.input
    completion_tokens = message.tokens.output
    Result.new(
      raw_response: raw_response_for(message, parsed),
      parsed: parsed,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
      total_tokens: total_for(prompt_tokens, completion_tokens)
    )
  end

  def self.parsed_hash(message)
    parsed = message.parsed
    parsed.is_a?(Hash) ? parsed : nil
  rescue JSON::ParserError
    nil
  end

  def self.raw_response_for(message, parsed)
    parsed ? JSON.generate(parsed) : message.content.to_s
  end

  def self.total_for(prompt_tokens, completion_tokens)
    return if prompt_tokens.nil? && completion_tokens.nil?

    prompt_tokens.to_i + completion_tokens.to_i
  end

  private_class_method :from_message, :parsed_hash, :raw_response_for, :total_for
end
