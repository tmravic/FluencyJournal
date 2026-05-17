class PrepareQuizPrompt < Prompt
  def role_prompt(user)
    "You are a helpful translator whose job it is to read my journal and translate each entry into " +
      "#{user.original_language}, keeping in mind the full content of the journal. " +
      "Each entry in this journal will be an item in an array. "
  end

  def response_format(journal)
    "Include json marker and return json in this exact format with exactly #{journal.full_journal.count} lines, " +
      "where each line corresponds to a line in #{journal.full_journal}: " +
      "{ { line_1: { translation: '... → ...', " +
      "line_2: { translation: '... → ...', " +
      "line_3: { translation: '... → ...', "
  end

  def change_keyword
    "translation_"
  end
end
