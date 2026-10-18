class AiQuery < ApplicationRecord
  belongs_to :journal, optional: true
  belongs_to :prompt
  delegate :user, to: :journal, allow_nil: true
  has_many :ai_outputs, dependent: :destroy
  has_many :origin_followups, class_name: "Followup", as: :origin, dependent: :nullify
  has_and_belongs_to_many :followups
  has_many :quizzes, dependent: :destroy
  has_many :quiz_hints, dependent: :destroy

  validates :prompt_tokens, :completion_tokens, :total_tokens, numericality: { only_integer: true }, allow_blank: true
  validates :raw_response, presence: true

  after_destroy -> {
    prompt.destroy!
  }

  def abbr(user)
    Prompt.abbr(user)
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

  def count_changes(string)
    # ["change_1", "change_2", "corrected_text"]
    parsed = parsed_response
    return 0 unless parsed.is_a?(Hash) && string.present?

    parsed.keys.count { |key| key.include?(string) }
    # => 2
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

  def create_quiz_questions(translated_response, expected_count: nil, quiz: nil)
    # Filter and sort only the real line_N keys the model actually returned
    line_keys = translated_response.keys
      .select { |k| k.match?(/\Aline_\d+\z/) }
      .sort_by { |k| k[/\d+/].to_i }

    actual = line_keys.size
    expected = expected_count || actual

    if expected > 0 && actual != expected
      Rails.logger.warn(
        "PrepareQuiz line-count mismatch: " \
        "journal_id=#{journal&.id} ai_query_id=#{id} prompt_id=#{prompt_id} " \
        "expected=#{expected} actual=#{actual} keys=#{line_keys.inspect} " \
        "raw_snippet=#{translated_response.to_json[0..800]}"
      )
    end

    # Always create *exactly* the expected number of quiz questions.
    # Use whatever the model gave us for the first min(actual, expected) items.
    # Hints are stored on quiz_hints, not as extra ai_outputs.
    (1..expected).each do |count|
      key = line_keys[count - 1] # may be nil if model gave fewer
      line = key ? translated_response[key] : nil
      translation = if key
                      translation_from_quiz_line(line)
                    else
                      fallback = line_keys.last && translated_response[line_keys.last]
                      translation_from_quiz_line(fallback) || "Translation missing"
                    end

      ai_outputs.create(
        made_note: false,
        identifier: count.to_s,
        role: :line
      ).tap do |ai_output|
        content = translation.to_s.split('→ ').last.presence || translation.to_s
        ai_output.content = content
        ai_output.save!
      end

      next unless quiz && (entry = journal&.entry_at(count))

      quiz.quiz_hints.create!(
        hint_content: hint_from_quiz_line(line) || "Hint missing",
        ai_query: self,
        entry: entry
      )
    end
  end

  def error_message
    "something went wrong"
  end

  CHANGE_CONTENT_ARROWS = [ "→", "⇒", "->", "↓" ].freeze

  def change_content(num, change_keyword)
    parsed = parsed_response
    return unless parsed.is_a?(Hash)

    result = parsed.dig("#{change_keyword}#{num}", "content")
    return present_change(result) if result

    backup_key = parsed.keys[num.to_i - 1]
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
      backup_key = parsed.keys[num.to_i - 1]
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

  def corrected_text
    content = parsed_response
    return textual(content) unless content.is_a?(Hash)

    %w[corrected_text corrected_japanese].each do |key|
      text = textual(content[key])
      return text if content.key?(key) && text
    end

    mirrored = content.find { |key, value| sentence_key?(key) && key == value.to_s }
    return mirrored.first if mirrored

    prose_from
  end

  def is_hash?(content)
    content.class == Hash
  end

  def transform_keys(hash, prefix = "answer_")
    return hash unless hash.is_a?(Hash) && hash["answers"]
    new_answers = {}
    hash["answers"].each do |old_key, value|
      new_key = "#{prefix}#{old_key}"
      new_answers[new_key] = value
    end
    # hash["answers"] = new_answers
    # hash
    new_answers
  end

  private

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
    parsed = transform_keys(parsed, "answer_") if parsed.is_a?(Hash) && parsed["answers"]
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
    text = result.is_a?(String) ? result : textual(result)
    return if text.blank?

    split_change_content(text)
  end

  def prose_from(wrapper_key = nil)
    content = parsed_response
    return textual(content) unless content.is_a?(Hash)

    if wrapper_key && content.key?(wrapper_key)
      return textual(content[wrapper_key])
    end

    textual(content.except(*item_keys(content)))
  end

  def text_from_explanation(value)
    return value if value.is_a?(String)
    return unless value.is_a?(Hash)

    picked = value.select { |key, _| key.to_s.match?(/explanation|reason|comment/i) }
    textual(picked.presence || value.except("content", "reading"))
  end

  def textual(value)
    case value
    when String
      value.strip.presence
    when Array
      value.filter_map { |item| textual(item) }.uniq.join("\n").presence
    when Hash
      value.flat_map { |key, item|
        text = textual(item)
        if text
          [ text ]
        elsif sentence_key?(key)
          [ key.strip ]
        else
          []
        end
      }.uniq.join("\n").presence
    end
  end

  def item_keys(content)
    content.keys.grep(/\A(?:entry|change|line|hint|answer)_\d+\z/)
  end

  def sentence_key?(key)
    return false unless key.is_a?(String)

    text = key.strip
    return false if text.blank? || text.match?(/\A\w+\z/)

    text.match?(/\p{Hiragana}|\p{Katakana}|\p{Han}/) || text.include?(" ")
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
