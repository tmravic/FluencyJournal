class EntryPrompt < Prompt
  def role_prompt(user, journal)
    "You are a helpful #{user.learning_language} teacher whose job it is to fix grammar mistakes " +
      "and reword journal entries into more natural and correct #{user.learning_language}. " +
      "'Learning Language' is the student's error-prone #{user.learning_language} attempt. " +
      "Correct it to match the 'Original Language' #{user.original_language} intent. " +
      "The journal entry may contain #{user.original_language} in 'Original Language' to clarify the " +
      "student's intended meaning, but ignore this if no #{user.original_language} is in the prompt. " +
      "If 'Learning Language' contains no #{user.learning_language}, but 'Original Language' has an " +
      "#{user.original_language} entry, then simply translate without any changes. " +
      "Each item in this array is part of a previous entry in this journal, which you " +
      "should not correct or comment on but refer to as context to understand the current entry: #{journal.full_journal}. " +
      "Avoid vague feedback, instead pointing out each change clearly. When the content of " +
      "'Original Language' is grammatically correct, don't make needless corrections that change the tone, " +
      "nuance, or politeness unless the student asks for it specifically. " +
      "Do not suggest adding a period at the end of sentences. "
  end

  def change_keyword
    "change_"
  end

  def response_format(user)
    "Include json marker and return json in this exact format (matching the number of changes/corrections and including the full corrected_text in #{user.learning_language}): " +
      "{ { #{self.change_keyword}1: { content: '... → ...', explanation_#{abbr(user)}: '...' }, " +
      "#{self.change_keyword}2: { content: '... → ...', explanation_#{abbr(user)}: '...' }, " +
      "#{self.change_keyword}3: { content: '... → ...', explanation_#{abbr(user)}: '...' }, " +
      "...," +
      "corrected_text: { '...' } } }"
    # {
    #   {
    #     change_1: { content: '... → ...', explanation_#{abbr(user)}: '...',
    #     change_2: { content: '... → ...', explanation_#{abbr(user)}: '...',
    #     change_3: { content: '... → ...', explanation_#{abbr(user)}: '...',
    #     ...,
    #     corrected_text: { '...' },
    #   }
    # }
  end

  def original_language
    base_content
  end

  def learning_language
    user_generated_content
  end
end
