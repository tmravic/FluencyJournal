class PrepareQuizPrompt < Prompt
  def role_prompt(user)
    "You are a helpful translator whose job it is to read my journal and translate EACH ENTRY into " +
      "#{user.original_language}, keeping in mind the full content of the journal. " +
      "The entries will be provided to you as a JSON array (and also shown below with explicit labels). " +
      "**Each element of that array is ONE ATOMIC JOURNAL ENTRY and must become exactly one quiz question.** " +
      "Never split the text inside any single array element / ENTRY into multiple quiz questions, even if it contains multiple sentences or Japanese periods (。)."
  end

  def response_format(journal)
    n = journal.full_journal.count
    entries_block = journal.full_journal.each_with_index.map do |entry, i|
      "ENTRY #{i+1}:\n#{entry}"
    end.join("\n\n")

    <<~PROMPT.strip
      CRITICAL INSTRUCTIONS - FOLLOW THESE EXACTLY:
      - You MUST return a JSON object with **exactly #{n}** top-level keys named line_1 through line_#{n}.
      - There is a 1-to-1 correspondence: each ENTRY below becomes exactly one line_X.
      - **NEVER** produce more or fewer than #{n} line_X keys.
      - **NEVER** split the content of one ENTRY across multiple line_X keys, even when the text contains "。" or multiple sentences. Each ENTRY is atomic.
      - The input array you received earlier and the labeled block below define the exact boundaries.

      INPUT JOURNAL ENTRIES (exactly #{n} atomic entries):

      #{entries_block}

      Return ONLY valid JSON in this exact shape (no extra keys, no extra line_N):
      {
        "line_1": { "translation": "Japanese text → English translation" },
        "line_2": { "translation": "..." },
        ...
        "line_#{n}": { "translation": "..." }
      }
    PROMPT
  end

  def change_keyword
    "translation_"
  end
end
