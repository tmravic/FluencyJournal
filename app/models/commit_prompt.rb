class CommitPrompt < Prompt
  # this will parse self.raw_response
  # into a format where I know what was the
  # system prompt sent in the AiRequestJob
  # as well as the note sent, original_language,
  # and learning_language

  def self.system_prompt(prompt_from_ai_request_params)

  end
end