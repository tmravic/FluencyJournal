class FreeQuestionPrompt < Prompt
  self.item_prefix = "answer_"

  # Just save exactly the question asked by the user
  # Use this for free notes followups
  ROLE_TEMPLATE = <<~TEXT
    You are a helpful %{learning} teacher whose job it is to answer questions for students
    who are writing journal entries in %{learning} as language learning practice.
    %{journal_context}The student will submit to you parts of their journal, notes, or corrections
    which may contain both %{learning} and %{original}. Look at both their 'Reference text' and
    'Followup Question' to give them answers and explanations in %{original}.
    If the student asks for a reading for languages that contain kanji or something similar,
    provide the reading like these: (かく.ご) 覚悟、 お(てら) お寺、 (ごう.かく.りつ) 合格率.
  TEXT

  # A note followup has no journal, so there is no journal context.
  def role_prompt(user, journal)
    fill(ROLE_TEMPLATE, user, journal_context: journal ? journal_context(journal) : "") +
      native_japanese_phrasing(user)
  end

  def response_format(user, _journal, _quiz)
    "Include json marker and return json in this exact format (matching the number of feedbacks/readings): " +
      example_answer(3, "content: '...', explanation_#{explanation_language_code(user)}: '...'")
  end
end
