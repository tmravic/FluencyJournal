class PrepareQuizPrompt < Prompt
  def role_prompt(user, _journal)
    "You are a helpful translator whose job it is to read my journal and translate EACH ENTRY into " +
      "#{user.original_language}, keeping in mind the full content of the journal. " +
      "The entries will be provided to you as a JSON array (and also shown below with explicit labels). " +
      "**Each element of that array is ONE ATOMIC JOURNAL ENTRY and must become exactly one quiz question.** " +
      "Never split the text inside any single array element / ENTRY into multiple quiz questions, even if it contains multiple sentences or Japanese periods (。). " +
      "For each entry, also write a short question in #{user.learning_language} that would help the student produce that entry as their answer. " +
      native_japanese_phrasing(user)
  end

  def response_format(user, journal, _quiz)
    entries = journal.full_journal
    n = entries.size
    learning_language = user.learning_language
    entries_block = entries.map.with_index(1) { |entry, i| "ENTRY #{i}:\n#{entry}" }.join("\n\n")

    <<~PROMPT.strip
      CRITICAL INSTRUCTIONS - FOLLOW THESE EXACTLY:
      - You MUST return a JSON object with **exactly #{n}** top-level keys named line_1 through line_#{n}.
      - There is a 1-to-1 correspondence: each ENTRY below becomes exactly one line_X.
      - **NEVER** produce more or fewer than #{n} line_X keys.
      - **NEVER** split the content of one ENTRY across multiple line_X keys, even when the text contains "。" or multiple sentences. Each ENTRY is atomic.
      - The input array you received earlier and the labeled block below define the exact boundaries.
      - Each line_X includes a translation and a hint. The hint is one short question in #{learning_language}.

      INPUT JOURNAL ENTRIES (exactly #{n} atomic entries):

      #{entries_block}

      Return ONLY valid JSON in this exact shape (no extra keys, no extra line_N):
      {
        "line_1": { "translation": "Japanese text → English translation", "hint": "short question in #{learning_language}" },
        "line_2": { "translation": "...", "hint": "..." },
        ...
        "line_#{n}": { "translation": "...", "hint": "..." }
      }
    PROMPT
  end

  # Must match the line_N keys that response_format asks for.
  def change_keyword
    "line_"
  end
end
