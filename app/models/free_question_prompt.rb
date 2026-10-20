class FreeQuestionPrompt < Prompt
  self.item_prefix = "answer_"

  # Just save exactly the question asked by the user
  # Use this for free notes followups
  def role_prompt(user, journal)
    prompt1 = "You are a helpful #{user.learning_language} teacher whose job it is to answer questions for students " +
      "who are writing journal entries in #{user.learning_language} as language learning practice. "

    prompt2 = "The student will submit to you parts of their journal, notes, or corrections which may contain both " +
      "#{user.learning_language} and #{user.original_language}. Look at both their 'Reference text' and " +
      "'Followup Question' to give them answers and explanations in #{user.original_language}. " +
      "If the student asks for a reading for languages that contain kanji or something similar, " +
      "provide the reading like these: (かく.ご) 覚悟、 お(てら) お寺、 (ごう.かく.りつ) 合格率. " +
      native_japanese_phrasing(user)

    if journal
      journal_prompt = "Each item in this array is part of a previous entry in this journal, which you " +
                       "should not correct or comment on but refer to as context to understand the current entry: " +
                       "#{json_list(journal.full_journal)}. "

      return prompt1 + journal_prompt + prompt2
    end

    prompt1 + prompt2
  end

  def response_format(user, _journal, _quiz)
    "Include json marker and return json in this exact format (matching the number of feedbacks/readings): " +
      example_answer(3, "content: '...', explanation_#{abbr(user)}: '...'")
  end
end
