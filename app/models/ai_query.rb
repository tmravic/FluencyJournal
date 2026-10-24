class AiQuery < ApplicationRecord
  belongs_to :journal, optional: true
  belongs_to :prompt
  delegate :user, to: :journal, allow_nil: true
  delegate :change_keyword, to: :prompt
  has_many :ai_outputs, dependent: :destroy
  has_many :followups, as: :origin, dependent: :nullify
  has_many :quizzes, dependent: :destroy, inverse_of: :ai_query
  has_many :graded_quizzes, class_name: "Quiz", foreign_key: :grading_ai_query_id, dependent: :nullify, inverse_of: :grading_ai_query
  has_many :quiz_hints, dependent: :destroy

  validates :prompt_tokens, :completion_tokens, :total_tokens, numericality: { only_integer: true }, allow_blank: true
  validates :raw_response, presence: true

  # Deleting this also deletes its prompt (and the prompt's other child).
  # See the comment on Prompt.
  after_destroy -> { Prompt.destroy_from(self) }

  # Stored on quiz rows when the model returns fewer lines than expected.
  MISSING_TRANSLATION = "Translation missing".freeze
  MISSING_HINT = "Hint missing".freeze
  LOG_SNIPPET_LENGTH = 800

  # An unsaved query for a model reply: the raw body, its token counts
  # (a hash with "prompt_tokens", "completion_tokens" and "total_tokens",
  # as XAiChat::Result#token_data), the prompt it answers and, when there is
  # one, the journal. The callers decide whether to count changes and save.
  def self.from_chat(raw_response:, token_data:, prompt:, journal: nil)
    query = build(
      prompt_tokens: token_data["prompt_tokens"],
      completion_tokens: token_data["completion_tokens"],
      total_tokens: token_data["total_tokens"],
      raw_response: raw_response
    )
    query.prompt = prompt
    query.journal = journal if journal
    query
  end

  # Builds the card for one item of the reply (a change line, the corrected
  # sentence or the assessment), assembles its text for user and saves it.
  # When the reply has nothing to show for it, nothing is saved and the
  # unsaved build is dropped from ai_outputs, so the query never lists a
  # card that did not reach the database. Returns the saved output or nil.
  def add_assembled_output(identifier:, role:, user:)
    output = ai_outputs.build(made_note: false, identifier: identifier, role: role)
    return output if output.save_assembled_content(change_keyword, user)

    ai_outputs.target.delete(output)
    nil
  end

  def find_ai_output_by_identifier(identifier)
    ai_outputs.find_by(identifier: identifier)
  end

  # {"change_1"=>
  #    {"content"=>"小さい針 → マイクロニードル",
  #     "explanation_en"=>"Changed '小さい針' to 'マイクロニードル' to use the correct term in Japanese."},
  #  "change_2"=>
  #    {"content"=>"太陽からの被害 → 日焼けによるダメージ",
  #     "explanation_en"=>"Changed '太陽からの被害' to '日焼けによるダメージ' to sound more natural in Japanese."},
  #  "corrected_text"=>{"text"=>"今日はシルファームという肌の施術を受けます。マイクロニードルとケミカルピーリングで何年間のニキビ跡と日焼けによるダメージを治療したいです。"}}
  #
  def parsed_response
    return @parsed_response if instance_variable_defined?(:@parsed_response)

    @parsed_response = parse_into_object
  end

  def raw_response=(value)
    forget_parsed_response
    super
  end

  def reload(*)
    forget_parsed_response
    super
  end

  # Counts the numbered items for a prompt's change keyword, e.g. "change_"
  # matches "change_1" and "change_2" but not "corrected_text" or "exchange_1".
  def count_changes(prefix)
    parsed = parsed_response
    return 0 unless parsed.is_a?(Hash) && prefix.present?

    pattern = /\A#{Regexp.escape(prefix)}\d/
    parsed.keys.count { |key| key.to_s.match?(pattern) }
  end

  # [before, after] for a change line, or nil when the model left it blank.
  def change_sides(num, change_keyword)
    content = change_content(num, change_keyword)
    return if content.blank?

    if content.is_a?(String)
      [ content, content ]
    elsif content.respond_to?(:first) && content.respond_to?(:last)
      [ content.first, content.last ]
    end
  end

  def model_used
    prompt.ai_model
  end

  # Prepared or graded a quiz (deleting it changes the quiz UI).
  def quiz_related?
    quizzes.exists? || graded_quizzes.exists?
  end

  def create_quiz_questions(translated_response, expected_count: nil, quiz: nil)
    line_keys = quiz_line_keys(translated_response)
    expected = expected_count || line_keys.size
    log_line_count_mismatch(translated_response, line_keys, expected)

    # Always create *exactly* the expected number of quiz questions.
    # Use whatever the model gave us for the first min(actual, expected) items.
    # Hints are stored on quiz_hints, not as extra ai_outputs.
    (1..expected).each do |count|
      key = line_keys[count - 1] # may be nil if model gave fewer
      line = key ? translated_response[key] : nil

      ai_outputs.create!(
        made_note: false,
        identifier: count.to_s,
        role: :line,
        content: quiz_question_text(translated_response, line_keys, key, line)
      )

      next unless quiz && (entry = journal&.entry_at(count))

      quiz.quiz_hints.create!(
        hint_content: hint_from_quiz_line(line) || MISSING_HINT,
        ai_query: self,
        entry: entry
      )
    end
  end

  def error_message
    I18n.t("ai_query.error")
  end

  CHANGE_CONTENT_ARROWS = [ "→", "⇒", "->", "↓" ].freeze

  def change_content(num, change_keyword)
    parsed = parsed_response
    return unless parsed.is_a?(Hash)

    result = parsed.dig("#{change_keyword}#{num}", "content")
    return present_change(result) if result

    backup_key = positional_key(parsed, num)
    result = backup_key && parsed.dig(backup_key, "content")
    return if result.nil? || (result.is_a?(String) && result.blank?)
    return result if result.is_a?(String)

    present_change(result)
  end

  def split_change_content(result)
    return result unless result.is_a?(String)

    arrow = CHANGE_CONTENT_ARROWS.find { |candidate| result.include?(candidate) }
    arrow ? result.split(arrow, 2) : result
  end

  def change_explanation(change_keyword, num, abbr)
    parsed = parsed_response
    return error_message unless parsed.is_a?(Hash)

    explanation = explanation_value(parsed, "#{change_keyword}#{num}", abbr)

    if explanation.nil?
      explanation = parsed.dig("#{change_keyword}#{num}")
    end

    if explanation.nil?
      backup_key = positional_key(parsed, num)
      explanation = explanation_value(parsed, backup_key, abbr)
    end

    return explanation if explanation.is_a?(String)

    text_from_explanation(explanation) || error_message
  end

  # Reads whatever object the model returned and returns the prose inside it.
  # A new key name does not need a new branch.
  def assessment
    prose_from("assessment")
  end

  # Keys the model may use for the full corrected sentence.
  CORRECTED_TEXT_KEYS = %w[corrected_text corrected_japanese].freeze

  def corrected_text_key?
    parsed = parsed_response
    parsed.is_a?(Hash) && CORRECTED_TEXT_KEYS.any? { |key| parsed.key?(key) }
  end

  def corrected_text
    content = parsed_response
    return Prose.from(content) unless content.is_a?(Hash)

    CORRECTED_TEXT_KEYS.each do |key|
      text = Prose.from(content[key])
      return text if content.key?(key) && text
    end

    mirrored = content.find { |key, value| Prose.sentence_key?(key) && key == value.to_s }
    return mirrored.first if mirrored

    prose_from
  end

  private

  def forget_parsed_response
    remove_instance_variable(:@parsed_response) if instance_variable_defined?(:@parsed_response)
  end

  # {"answers" => {"1" => ...}} becomes {"answer_1" => ...}.
  def prefixed_answers(hash, prefix = "answer_")
    return hash unless hash.is_a?(Hash) && hash["answers"]

    hash["answers"].to_h { |old_key, value| [ "#{prefix}#{old_key}", value ] }
  end

  # When the model numbers its items differently than asked, the Nth item
  # is the Nth key of the response, whatever its name.
  def positional_key(parsed, num)
    parsed.keys[num.to_i - 1]
  end

  def explanation_value(parsed, key, abbr)
    return if key.nil?

    value = parsed.dig(key, "explanation_#{abbr}")
    return value unless value.nil?
    return unless abbr == "ja"

    parsed.dig(key, "explanation_jp")
  end

  def parse_into_object
    parsed = parse_raw_response
    parsed = JSON.parse(parsed) if parsed.is_a?(String)
    parsed = prefixed_answers(parsed, "answer_") if parsed.is_a?(Hash) && parsed["answers"]
    parsed
  rescue JSON::ParserError
    nil
  end

  def parse_raw_response
    JSON.parse(raw_response)
  rescue JSON::ParserError
    JSON.parse(json_without_markdown_fences)
  end

  def json_without_markdown_fences
    raw_response.to_s.sub(/\A\s*```(?:json)?\s*/i, "").sub(/\s*```\s*\z/, "").strip
  end

  def present_change(result)
    text = result.is_a?(String) ? result : Prose.from(result)
    return if text.blank?

    split_change_content(text)
  end

  def prose_from(wrapper_key = nil)
    content = parsed_response
    return Prose.from(content) unless content.is_a?(Hash)

    if wrapper_key && content.key?(wrapper_key)
      return Prose.from(content[wrapper_key])
    end

    Prose.from(content.except(*item_keys(content)))
  end

  def text_from_explanation(value)
    return value if value.is_a?(String)
    return unless value.is_a?(Hash)

    picked = value.select { |key, _| key.to_s.match?(/explanation|reason|comment/i) }
    Prose.from(picked.presence || value.except("content", "reading"))
  end

  def item_keys(content)
    content.keys.grep(/\A(?:entry|change|line|hint|answer|example)_\d+\z/)
  end

  # Only the real line_N keys the model returned, in numeric order.
  def quiz_line_keys(translated_response)
    translated_response.keys
      .select { |k| k.match?(/\Aline_\d+\z/) }
      .sort_by { |k| k[/\d+/].to_i }
  end

  def log_line_count_mismatch(translated_response, line_keys, expected)
    actual = line_keys.size
    return unless expected > 0 && actual != expected

    Rails.logger.warn(
      "PrepareQuiz line-count mismatch: " \
      "journal_id=#{journal&.id} ai_query_id=#{id} prompt_id=#{prompt_id} " \
      "expected=#{expected} actual=#{actual} keys=#{line_keys.inspect} " \
      "raw_snippet=#{translated_response.to_json[0, LOG_SNIPPET_LENGTH]}"
    )
  end

  # The question's text: the model's translation (the part after the last
  # '→ '), or, for a line the model did not return, the last returned
  # line's translation, or MISSING_TRANSLATION.
  def quiz_question_text(translated_response, line_keys, key, line)
    translation = if key
                    translation_from_quiz_line(line)
                  else
                    fallback = line_keys.last && translated_response[line_keys.last]
                    translation_from_quiz_line(fallback) || MISSING_TRANSLATION
                  end

    translation.to_s.split("→ ").last.presence || translation.to_s
  end

  def translation_from_quiz_line(line)
    case line
    when Hash
      line["translation"]
    when String
      line
    end
  end

  def hint_from_quiz_line(line)
    return unless line.is_a?(Hash)

    hint = line["hint"]
    hint = hint["content"] if hint.is_a?(Hash)
    hint.to_s.presence
  end
end
