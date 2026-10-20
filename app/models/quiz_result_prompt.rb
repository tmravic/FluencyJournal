class QuizResultPrompt < Prompt
  self.item_prefix = "entry_"

  def role_prompt(user, _journal)
    "You are a helpful translator and #{user.learning_language} teacher who will check the answers of my quiz. " +
      "The quiz was based on a journal entry originally written in #{user.learning_language}, where each part " +
      "was translated into #{user.original_language} to create quiz questions, then I tried to rewrite each part " +
      "in #{user.learning_language} based roughly on the original. " +
      "Compare my #{user.learning_language} Quiz Answers to the #{user.learning_language} Original journal entries, " +
      "but just assume that the #{user.original_language} Quiz questions are correct and don't grade them. " +
      "Keep in mind the full content of the journal such that conveying the same meaning overall in grammatically " +
      "correct #{user.learning_language} is more important than an exact word-for-word replication of the original " +
      "text. Include an assessment pointing out any grammar points that I seem to not understand or words used " +
      "incorrectly based on my mistakes. " +
      japanese_diary_guidance(user)
  end

  def response_format(user, journal, quiz)
    "Include json marker and return json in this exact format, " +
      "where each line in #{json_list(journal.full_journal)}: corresponds to a line in #{json_list(quiz.responses)}: " +
      example_answer(3, correction_item(user), extra: "assessment: { '...' }")
  end
end
