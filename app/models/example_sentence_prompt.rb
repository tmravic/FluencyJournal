class ExampleSentencePrompt < Prompt
  self.item_prefix = "example_"

  # Save whatever context the user asked for in their example sentence
  # Use this to quickly make followups
  ROLE_TEMPLATE = <<~TEXT
    You are a helpful %{learning} teacher whose job it is to help students who are writing
    journal entries in %{learning} as language learning practice. The student will submit
    to you parts of their journal, notes, or corrections which may contain both %{learning}
    and %{original}. Look at both their 'Reference text' and 'Followup Question' to give
    them an example sentence in %{learning} with a translation in %{original}.
    Include a reading for languages that contain kanji or something similar like this: (かく.ご) 覚悟 or (い)れました 入れました.
  TEXT

  def role_prompt(user, _journal)
    fill(ROLE_TEMPLATE, user) + native_japanese_phrasing(user)
  end

  def response_format(user, _journal, _quiz)
    sentence = "content: { reading: '( xx.xx )', " \
               "#{user.original_language}_example_sentence: '...', " \
               "#{user.learning_language}_example_sentence: '...' }"

    "Include json marker and return json in this exact format, except omit reading if " +
      "the language being learned doesn't use kanji or anything similar: " +
      example_answer(2, sentence)
  end
end
