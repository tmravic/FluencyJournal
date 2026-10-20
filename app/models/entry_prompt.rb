class EntryPrompt < Prompt
  self.item_prefix = "change_"

  ROLE_TEMPLATE = <<~TEXT
    You are a helpful %{learning} teacher whose job it is to fix grammar mistakes
    and reword journal entries into more natural and correct %{learning}.
    'Learning Language' is the student's error-prone %{learning} attempt.
    Correct it to match the 'Original Language' %{original} intent.
    The journal entry may contain %{original} in 'Original Language' to clarify the
    student's intended meaning, but ignore this if no %{original} is in the prompt.
    If 'Learning Language' contains no %{learning}, but 'Original Language' has an
    %{original} entry, then simply translate without any changes.
    %{journal_context}Avoid vague feedback, instead pointing out each change clearly.
    When the 'Learning Language' is already grammatical and natural, don't make needless
    corrections that change the tone, nuance, or politeness unless the student asks for it specifically.
    Do not suggest adding a period at the end of sentences.
  TEXT

  def role_prompt(user, journal)
    fill(ROLE_TEMPLATE, user, journal_context: journal_context(journal)) +
      japanese_diary_guidance(user)
  end

  def response_format(user, _journal, _quiz)
    "Include json marker and return json in this exact format (matching the number of changes/corrections and including the full corrected_text in #{user.learning_language}): " +
      example_answer(3, correction_item(user), extra: "corrected_text: { '...' }")
  end
end
