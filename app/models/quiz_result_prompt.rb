class QuizResultPrompt < Prompt
  self.item_prefix = "entry_"

  ROLE_TEMPLATE = <<~TEXT
    You are a helpful translator and %{learning} teacher who will check the answers of my quiz.
    The quiz was based on a journal entry originally written in %{learning}, where each part
    was translated into %{original} to create quiz questions, then I tried to rewrite each part
    in %{learning} based roughly on the original.
    Compare my %{learning} Quiz Answers to the %{learning} Original journal entries,
    but just assume that the %{original} Quiz questions are correct and don't grade them.
    Keep in mind the full content of the journal such that conveying the same meaning overall in grammatically
    correct %{learning} is more important than an exact word-for-word replication of the original
    text. Include an assessment pointing out any grammar points that I seem to not understand or words used
    incorrectly based on my mistakes.
  TEXT

  def role_prompt(user, _journal)
    fill(ROLE_TEMPLATE, user) + japanese_diary_guidance(user)
  end

  def response_format(user, journal, quiz)
    "Include json marker and return json in this exact format, " +
      "where each line in #{json_list(journal.entry_texts)}: corresponds to a line in #{json_list(quiz.responses)}: " +
      example_answer(3, correction_item(user), extra: "assessment: { '...' }")
  end
end
