class ExampleSentencePrompt < Prompt
  # Save whatever context the user asked for in their example sentence
  # Use this to quickly make followups
  def role_prompt(user)
    "You are a helpful #{user.learning_language} teacher whose job it is to help students who are writing " +
      "journal entries in #{user.learning_language} as language learning practice. The student will submit " +
      "to you parts of their journal, notes, or corrections which may contain both #{user.learning_language} " +
      "and #{user.original_language}. Look at both their 'Reference text' and 'Followup Question' to give " +
      "them an example sentence in #{user.learning_language} with a translation in #{user.original_language}. " +
      "Include a reading for languages that contain kanji or something similar like this: (かく.ご) 覚悟."
  end

  def change_keyword
    'example_'
  end

  def response_format(user)
    "Include json marker and return json in this exact format, except omit reading if " +
    "the language being learned doesn't use kanji or anything similar: " +
    "{ { #{self.change_keyword}1: { content: { reading: '( xx.xx )', " +
    "#{user.original_language}_example_sentence: '...', " +
    "#{user.learning_language}_example_sentence: '...' } }, " +
    "#{self.change_keyword}2: { content: { reading: '( xx.xx )', " +
    "#{user.original_language}_example_sentence: '...', " +
    "#{user.learning_language}_example_sentence: '...' } } } }"
    # {
    #   {
    #     example_1: {
    #       content: {
    #         reading: '( xx.xx )',
    #         #{user.original_language}_example_sentence: '...',
    #         #{user.learning_language}_example_sentence: '...'
    #       }
    #     },
    #     example_2: {
    #       content: {
    #         reading: '( xx.xx )',
    #         #{user.original_language}_example_sentence: '...',
    #         #{user.learning_language}_example_sentence: '...'
    #       }
    #     }
    #   }
    # }
  end

  def followup_question
    base_content
  end

  def reference_text
    user_generated_content
  end
end
