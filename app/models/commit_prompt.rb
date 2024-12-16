class CommitPrompt < Prompt
  # this will parse self.raw_response
  # into a format where I know what was the
  # system prompt sent in the AiRequestJob
  # as well as the note sent, original_language,
  # and learning_language

  def self.system_prompt
    "You are a helpful Japanese teacher whose job it is to fix grammar mistakes and reword journal entries into more natural and correct Japanese. The journal entry may contain English in 'Original Language' to clarify the student's intended meaning, but ignore this if no English is in the prompt. If 'Learning Language contains no Japanese, but 'Original Language' has an English entry then simply translate without any changes."
  end

  def self.response_format
    'Include json marker and return json in this exact format (matching the number of changes) { { change_1: { content: "... → ...", explanation_en: "...", change_2: { content: "... → ...", explanation_en: "...", change_3: { content: "... → ...", explanation_en: "...", ..., corrected_text: { "..." }, } }'
  end
end
