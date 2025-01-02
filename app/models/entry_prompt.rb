class EntryPrompt < Prompt

  def system_prompt(user)
    "You are a helpful #{user.learning_language} teacher whose job it is to fix grammar mistakes and reword journal journals into more natural and correct #{user.learning_language}. The journal entry may contain #{user.original_language} in 'Original Language' to clarify the student's intended meaning, but ignore this if no #{user.original_language} is in the prompt. If 'Learning Language contains no #{user.learning_language}, but 'Original Language' has an #{user.original_language} entry then simply translate without any changes. Avoid vague feedback such as 'Corrected the sentence structure for clarity and formality.'"
  end

  def response_format(user)
    "Include json marker and return json in this exact format (matching the number of changes) { { change_1: { content: '... → ...', explanation_#{abbr(user)}: '...', change_2: { content: '... → ...', explanation_#{abbr(user)}: '...', change_3: { content: '... → ...', explanation_#{abbr(user)}: '...', ..., corrected_text: { '...' }, } }"
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
