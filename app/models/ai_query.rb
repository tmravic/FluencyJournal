class AiQuery < ApplicationRecord
  LANGUAGE_ABBREVIATIONS = { "English" => "en", "Japanese" => "jp" }

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
  def parsed_response(string)
    parsed_response = sanitized_response(string)
    if parsed_response["answers"]
      parsed_response = transform_keys(parsed_response, "answer_")
    end
    parsed_response
  end

  def count_changes(string)
    # ["change_1", "change_2", "corrected_text"]

    parsed_response(string).keys.count { |key| key.include?(string) }
    # => 2
  end

  def sanitized_response(string)
    raw = prepare_raw
    raw = normalize_whitespace(raw)
    raw = substitute_alphanumeric(raw)
    raw = add_closing_brace(raw)
    JSON.parse(raw) rescue sanitized_response2(string)
  end

  def sanitized_response2(string)
    raw = prepare_raw(options: {encode: true})
    raw = normalize_whitespace(raw)
    raw = add_commas_variant1(raw)
    raw = substitute_alphanumeric(raw)
    raw = quote_values_variant1(raw)
    raw = add_closing_brace(raw)
    JSON.parse(raw) rescue sanitized_response3(string)
  end

  def sanitized_response3(string)
    raw = prepare_raw(options: {encode: true})
    raw = normalize_whitespace(raw)
    raw = add_commas_variant2(raw)
    raw = substitute_alphanumeric(raw)
    raw = quote_values_variant2(raw)
    raw = add_closing_brace(raw)
    JSON.parse(raw) rescue sanitized_response4(string)
  end

  def sanitized_response4(string)
    raw = prepare_raw(options: {encode: true, scrub: true})
    raw = normalize_whitespace(raw)
    raw = add_commas_variant2(raw)
    raw = substitute_alphanumeric(raw)
    raw = quote_values_variant2(raw)
    raw = remove_trailing_commas(raw)
    raw = add_closing_brace(raw)
    JSON.parse(raw) rescue sanitized_response5(string)
  end

  def sanitized_response5(string)
    hash = {}

    regex1 = /corrected_text:\s*([^"]+)/
    regex2 = /corrected_text:\s*(.+)$/m
    match_corrected_text = self.raw_response.match(regex1) || self.raw_response.match(regex2)
    hash["corrected_text"] = extract_corrected_text(match_corrected_text) if match_corrected_text

    regex_pattern = sanitizing_regex(string)
    hash = scan_raw_response_for_pattern(hash, regex_pattern, string)
    if hash.empty?
      return sanitized_response6(string)
    end
    hash
  end

  def sanitized_response6(string)
    raw = normalize_whitespace(self.raw_response)
    raw = substitute_alphanumeric(raw)
    raw = quote_values_variant2(raw)
    raw = add_closing_brace(raw)
    parsed = JSON.parse(raw) rescue {}
    if parsed && parsed["answers"]
      parsed["answers"].each do |num, data|
        hash["#{string}#{num}"] = data
      end
    end
  end

  def model_used
    prompt.ai_model
  end

  def create_quiz_questions(translated_response)
    line_count = translated_response.keys.count
    (1..line_count).each do |count|
      ai_outputs.create(
        made_note: false,
        identifier: count.to_s
      ).tap do |ai_output|
        # Did I add translation but this is specific to PrepareQuizJob?
        ai_output.content = translated_response.dig("line_#{count}", "translation").split('→ ').last
        # ["明日、彼女のお母さんに初めて会う予定です。 ",
        #  "Tomorrow, I have plans to meet her mother for the first time."]
        ai_output.save!
      end
    end
  end

  def error_message
    "something went wrong"
  end

  def change_content(num, change_keyword)
    result = parsed_response(change_keyword).dig("#{change_keyword}#{num}", "content")
    if result
      if result.include?("→")
        return result.split("→")
      else
        return result
      end
    end

    error_message
  end

  def change_explanation(change_keyword, num, abbr)
    parsed_response(change_keyword).dig("#{change_keyword}#{num}", "explanation_#{abbr}") || error_message
  end

  def assessment
    content = self.parsed_response("assessment")

    # {"overall"=> "Overall, the quiz answers are..."}
    return content["overall"] if is_hash?(content) && content["overall"]

    # {"overall_accuracy"=> "The translations are mostly accurate..."}
    return content["overall_accuracy"] if is_hash?(content) && content["overall_accuracy"]

    content
  end

  def corrected_text
    # Sometimes a string is returned and sometimes it's a Hash
    content = parsed_response("corrected_text")

    # When the user input nothing
    # {"..."=>0}
    return "No content" if is_hash?(content) && content["..."]

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

    #  {"Today was such a hot day."=>""}
    if is_hash?(content) && content.values.first.empty?
      return content.keys.first
    end

    #  "昨年のクリスマスに私はあなたに心を捧げました"
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

  private

  def scan_raw_response_for_pattern(hash, regex_pattern, string)
    self.raw_response.scan(regex_pattern) do |num, cont, exp|
      hash["#{string}#{num}"] = {
        "content" => cont.strip.gsub(/\"/, ''),
        "explanation_en" => exp.strip.gsub(/\"/, '')
      }
    end
    hash
  end

  def normalize_whitespace(raw)
    raw.gsub(/\n/, ' ').gsub(/\s+/, ' ')
  end

  def substitute_alphanumeric(raw)
    raw.gsub(/([a-z0-9_]+)\s*:/i, '"\1":')
  end

  def prepare_raw(base_raw = self.raw_response || "{}", options = {})
    base_raw = base_raw.to_s if base_raw.is_a?(Hash)
    raw = base_raw.strip
    raw = raw.force_encoding('UTF-8') if options[:encode]
    raw = raw.scrub if options[:scrub]
    raw
  end

  def add_closing_brace(raw)
    raw += ' }' unless raw.end_with?('}')
    raw
  end

  def add_commas_variant1(raw)
    raw.gsub(/([^{:\s])\s+([a-z0-9_]+:)/i, '\1,\2')
  end

  def add_commas_variant2(raw)
    raw.gsub(/([}\"])\s+([a-z0-9_]+)\s*:/i, '\1, "\2":')
  end

  def quote_values_variant1(raw)
    raw.gsub(/:\s*([^"{\[0-9tfn].*?)\s*(?=[,}\]])/m, ': "\1"')
  end

  def quote_values_variant2(raw)
    raw.gsub(/:\s*([^",{\[\]]+?)\s*(?=[,}\]]|$)/, ': "\1"')
  end

  def remove_trailing_commas(raw)
    raw.gsub(/,\s*([}\]])/, '\1')
  end

  def extract_corrected_text(match)
    match ? match[1].strip.gsub(/\"/, '') : ''
  end

  def sanitizing_regex(string)
    /#{Regexp.escape(string)}(\d+):.*?content:\s*([^,]+).*?explanation_en:\s*([^}]+)/m
  end
end
