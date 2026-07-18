class QuizResultPrompt < Prompt
  def role_prompt(user)
    "You are a helpful translator and #{user.learning_language} teacher who will check the answers of my quiz. " +
      "The quiz was based on a journal entry originally written in #{user.learning_language}, where each part " +
      "was translated into #{user.original_language} to create quiz questions, then I tried to rewrite each part " +
      "in #{user.learning_language} based roughly on the original." +
      "Compare my #{user.learning_language} Quiz Answers to the #{user.learning_language} Original journal entries, " +
      "but just assume that the #{user.original_language} Quiz questions are correct and don't grade them. " +
      "Keep in mind the full content of the journal such that conveying the same meaning overall in grammatically " +
      "correct #{user.learning_language} is more important than an exact word-for-word replication of the original " +
      "text. Include an assessment pointing out any grammar points that I seem to not understand or words used " +
      "incorrectly based on on my mistakes."
  end

  def change_keyword
    "entry_"
  end

  def response_format(journal, quiz, user)
    "Include json marker and return json in this exact format, " +
      "where each line in #{journal.full_journal}: corresponds to a line in #{quiz.full_journal}: " +
      "{ { #{self.change_keyword}1: { content: '... → ...', explanation_#{abbr(user)}: '...' }, " +
      "#{self.change_keyword}2: { content: '... → ...', explanation_#{abbr(user)}: '...' }, " +
      "#{self.change_keyword}3: { content: '... → ...', explanation_#{abbr(user)}: '...' }, " +
      "...," +
      "assessment: { '...' } } }"
    # {
    #   {
    #     entry_1: { content: '... → ...', explanation_#{abbr(user)}: '...',
    #     entry_2: { content: '... → ...', explanation_#{abbr(user)}: '...',
    #     entry_3: { content: '... → ...', explanation_#{abbr(user)}: '...',
    #     ...,
    #     assessment: { '...' },
    #   }
    # }
  end
end