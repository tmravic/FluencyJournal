class CommitPrompt < Prompt
  # this will parse self.raw_response
  # into a format where I know what was the
  # system prompt sent in the AiRequestJob
  # as well as the note sent, original_language,
  # and learning_language

  def self.system_prompt
    "You are a helpful Japanese teacher whose job it is to fix grammar mistakes and reword journal entries into more natural and correct Japanese. The journal entry may contain English in 'Original Language' to clarify the student's intended meaning, but ignore this if no English is in the prompt. If 'Learning Language contains no Japanese, but 'Original Language' has an English entry then simply translate without any changes."
  end

  def self.response_format
    'Include json marker and return json in this exact format (matching the number of changes) { { change_1: { content: "... → ...", explanation_en: "...", change_2: { content: "... → ...", explanation_en: "...", change_3: { content: "... → ...", explanation_en: "...", ..., corrected_text: { "..." }, } }'
  end
end

{
  "change_1" => {
  "content" => "filling → 詰め物",
  "explanation_en" => "The English word 'filling' should be replaced with the Japanese term '詰め物' for clarity and correctness."
  },
  "change_2" => {
    "content" => "root canalをせずに → 根管治療を受けずに",
    "explanation_en" => "The English term 'root canal' should be translated to '根管治療' for proper context and use in Japanese."
  },
  "change_3" => {
    "content" => "歯医者に行った → 歯医者さんに行った",
    "explanation_en" => "Using '歯医者さん' instead of '歯医者' adds a more polite and conversational tone."},
  "corrected_text" => "二日前、歯の詰め物がかけたので、根管治療を受けずに修理をしたかったから歯医者さんに行った。"
}
