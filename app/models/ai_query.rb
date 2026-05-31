class AiQuery < ApplicationRecord
  LANGUAGE_ABBREVIATIONS = { "English" => "en", "Japanese" => "jp" }
  include SanitizingHelper

  belongs_to :journal, optional: true
  belongs_to :prompt
  delegate :user, to: :journal, allow_nil: true
  has_many :ai_outputs, dependent: :destroy
  has_many :origin_followups, class_name: "Followup", as: :origin, dependent: :nullify
  has_and_belongs_to_many :followups
  has_many :quizzes, dependent: :destroy

  validates :prompt_tokens, :completion_tokens, :total_tokens, numericality: { only_integer: true }, allow_blank: true
  validates :raw_response, presence: true

  after_destroy -> {
    prompt.destroy!
  }

  def abbr(user)
    # This same thing exists on Prompt
    LANGUAGE_ABBREVIATIONS.fetch(user.original_language, "English")
  end

  def find_ai_output_by_identifier(identifier)
    self.ai_outputs.find { |output| output.identifier == identifier }
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
    parsed_response = JSON.parse(self.raw_response) rescue sanitized_response

    if parsed_response.kind_of?(String)
      parsed_response = JSON.parse(parsed_response)
    end
    if parsed_response["answers"]
      parsed_response = transform_keys(parsed_response, "answer_")
    end
    parsed_response
  end

  def count_changes(string)
    # ["change_1", "change_2", "corrected_text"]
    parsed_response.keys.count { |key| key.include?(string) }
    # => 2
  end

  def model_used
    prompt.ai_model
  end

  def create_quiz_questions(translated_response, expected_count: nil)
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
    (1..expected).each do |count|
      key = line_keys[count - 1] # may be nil if model gave fewer
      translation = if key
                      translated_response.dig(key, "translation")
                    else
                      # graceful fallback if model under-returned
                      (line_keys.last && translated_response.dig(line_keys.last, "translation")) || "Translation missing"
                    end

      ai_outputs.create(
        made_note: false,
        identifier: count.to_s
      ).tap do |ai_output|
        content = translation.to_s.split('→ ').last.presence || translation.to_s
        ai_output.content = content
        ai_output.save!
      end
    end
  end

  def error_message
    "something went wrong"
  end

  def change_content(num, change_keyword)
    parsed = parsed_response
    result = parsed.dig("#{change_keyword}#{num}", "content")
    if result
      if result.include?("→")
        return result.split("→")
      else
        return result
      end
    end

    if result.nil?
      backup_key = parsed.keys[num.to_i - 1]
      result = parsed.dig(backup_key, "content")
      return result
    end

    if result.nil?
      result = error_message
    end

    result
  end

  def change_explanation(change_keyword, num, abbr)
    parsed = parsed_response
    explanation = parsed.dig("#{change_keyword}#{num}", "explanation_#{abbr}")

    if explanation.nil?
      explanation = parsed.dig("#{change_keyword}#{num}")
    end

    if explanation.nil?
      backup_key = parsed.keys[num.to_i - 1]
      explanation = parsed.dig(backup_key, "explanation_#{abbr}")
      # {
      #   "answer_例文" => {
      #     "content" => "ほとんど一夜にして、東京は雪景色になった。",
      #     "explanation_en" => "This sentence uses the phrase 'ほとんど一夜にして' to indicate that the change happened almost overnight. The sentence translates to 'Almost overnight, Tokyo became a winter wonderland.'"
      #   },
      #   "answer_例文2" => {
      #     "content" => "彼は一瞬のうちに決断を下した。",
      #     "explanation_en" => "This sentence uses the phrase '一瞬のうちに' to indicate that the decision was made in an instant. The sentence translates to 'He made the decision in an instant.'"
      #   }
      # }
    end

    if explanation.nil?
      explanation = error_message
    end

    explanation
  end

  def assessment
    content = self.parsed_response

    # {"overall"=> "Overall, the quiz answers are..."}
    return content["overall"] if is_hash?(content) && content["overall"]

    # {"overall_accuracy"=> "The translations are mostly accurate..."}
    return content["overall_accuracy"] if is_hash?(content) && content["overall_accuracy"]

    return content["main_points"] if is_hash?(content) && content["main_points"]

    # {"grammar_points"=>"Particle usage (へ vs せずに) and noun phrase ..."}
    return content["grammar_points"] if is_hash?(content) && content["grammar_points"]

    # content.keys
    # ["entry_1", "entry_2", "entry_3", "entry_4", "assessment"]
    # content.dig("assessment")
    # {"overall_accuracy"=> "..."
    if is_hash?(content) && is_hash?(content.dig("assessment")) && content.dig("assessment", "overall_accuracy")
      return content.dig("assessment", "overall_accuracy")
    end

    if is_hash?(content) && is_hash?(content.dig("assessment")) && content.dig("assessment", "overall")
      return content.dig("assessment", "overall")
    end

    return content["assessment"] if is_hash?(content) && content["assessment"]

    content
  end

  def corrected_text
    # Sometimes a string is returned and sometimes it's a Hash
    content = parsed_response
    # {
    #   "change_1"=>
    #    { "content" => "ryokan → 旅館", "explanation_en"=>"「ryokan」は日 本語で「旅館」を意味するため、正しい表現に修正しました。" },
    #   "change_2"=>
    #     { "content" => "私立の外の露天風呂", "explanation_en"=>"「私立」は「個人的な」や「私有の」を意味するため、正しい表現に修正しました。" },
    #   "change_3"=>
    #     { "content" => "良寛のようやく", "explanation_en"=>"「 ようやく」は「ようやく」で正しい表現です。" },
    #   "corrected_text" => "外の露天風呂がある旅館を作る"
    # }

    # When the user input nothing
    # {"..."=>0}
    return "No content" if is_hash?(content) && content["..."]

    return content[""] if is_hash?(content) && content[""]

    # {"お時間がかかってしまい申し訳ございません。"=>"お時間がかかってしまい申し訳ございません。"}
    return content.keys.first if is_hash?(content) && content.keys.first == content.values.first

    #  {"text"=>"昨年のクリスマスに心をあげた"},
    #  {"text"=>"昨年のクリスマスに私はあなたに心を捧げました"}]
    return content["text"] if is_hash?(content) && content["text"]

    # {"内容"=>"昨日は病院でバリウムを飲んだ後遺症に苦しんだ。"}
    return content["内容"] if is_hash?(content) && content["内容"]

    # {"内容"=>"昨日は病院でバリウムを飲んだ後遺症に苦しんだ。"}
    return content["content"] if is_hash?(content) && content["content"]

    # {"corrected_japanese"=>"昨日は病院でバリウムを飲んだ後遺症に苦しんだ。"}
    return content["corrected_japanese"] if is_hash?(content) && content["corrected_japanese"]

    # { "corrected_text"=>
    #   {"リフレッシュする自然の景色のおかげで、私たちの態度と心境はほとんど一夜にして変わりました。"=>"This is the full corrected sentence in natural Japanese."} }
    # TODO: handle this case with a regex pattern which returns either key or value if either one has no alphabet characters.

    # {"corrected_text"=>"今になって、その仕事の教師たちと今はもう会わない"}
    return content["corrected_text"] if is_hash?(content) && content["corrected_text"]

    # {"text"=>"仕事で上司に「ITパスポート」という資格を取るように頼まれました"}
    return content["text"] if is_hash?(content) && content["text"]

    #  {"Today was such a hot day."=>""}
    if is_hash?(content) && content.values.first.empty?
      return content.keys.first
    end

    #  "昨年のクリスマスに私はあなたに心を捧げました"
    if content["corrected_text"].keys.first == content["corrected_text"].values.first
      return content["corrected_text"].values.first
    end

    content
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
end
