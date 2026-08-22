class QuizHintPrompt < Prompt
  def role_prompt(user, journal)
    "You are a helpful language teacher whose job it is to read my journal, and for each entry, ask me in " +
      "#{user.learning_language} a question that acts as a prompt for me to answer with the next line. " +
      native_japanese_phrasing(user)
  end

  def self.change_keyword
    "hint_"
  end

  def response_format(user, journal)
    n = journal.entries.count
    entries_block = journal.full_journal.each_with_index.map do |entry, index|
      "ENTRY #{index + 1}:\n#{entry}"
    end

    entries_block = entries_block.join("\n\n")

    <<~PROMPT.strip
      Return ONLY valid JSON with exactly #{n} keys: hint_1 through hint_#{n}
      Each hint_i is a short question in the #{user.learning_language} that would help the student produce ENTRY i as their answer.

    #{entries_block}

    {
      "hint_1": { "content": "..." },
      "hint_2": { "content": "..." },
      ...
      "hint_#{n}": { "content": "..." }
    }
    PROMPT

    # {
    #   hint_1: { "content": "..." },
    #   hint_2: { "content": "..." },
    #   hint_3: { "content": "..." }
    # }
  end
end
