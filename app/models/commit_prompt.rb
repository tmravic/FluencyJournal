class CommitPrompt < Prompt
  # this will parse self.raw_response
  # into a format where I know what was the
  # system prompt sent in the AiRequestJob
  # as well as the note sent, original_language,
  # and learning_language

  def self.original_language
    "English"
  end

  def self.learning_language
    "Japanese"
  end

  def self.system_prompt
    "You are a helpful #{learning_language} teacher whose job it is to fix grammar mistakes and reword journal entries into more natural and correct #{learning_language}. The journal entry may contain #{original_language} in 'Original Language' to clarify the student's intended meaning, but ignore this if no #{original_language} is in the prompt. If 'Learning Language contains no #{learning_language}, but 'Original Language' has an #{original_language} entry then simply translate without any changes."
  end

  def self.response_format
    'Include json marker and return json in this exact format (matching the number of changes) { { change_1: { content: "... → ...", explanation_en: "...", change_2: { content: "... → ...", explanation_en: "...", change_3: { content: "... → ...", explanation_en: "...", ..., corrected_text: { "..." }, } }'
  end

  def parsed_prompt
    lines = self.raw_prompt.split("\n")
    #  ["Original Language: The very next day you gave it away.", "Learning Language: 次の日にそれを捨てた。"]

    first = lines.first if lines.first[0, 18] == "Original Language:"
    last = lines.last if lines.last[0, 18] == "Learning Language:"

    [first, last]
  end

  def original_language
    parsed_prompt.first
  end

  def learning_language
    parsed_prompt.last
  end
end
