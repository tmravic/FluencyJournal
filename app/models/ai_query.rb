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
  def parsed_response
    parsed_response = sanitized_response
    parsed_response
  end

  def count_changes(string)
    # ["change_1", "change_2", "corrected_text"]
    parsed_response.keys.count { |key| key.include?(string) }
    # => 2
  end

  def sanitized_response
    raw = self.raw_response.gsub(/\n/, ' ').gsub(/\s+/, ' ')
    raw = raw.gsub(/([a-z0-9_]+)\s*:/i, '"\1":')
    raw += ' }' unless raw.end_with?('}')
    JSON.parse(raw) rescue sanitized_response2
  end

  def sanitized_response2
    raw = (self.raw_response || "{}").strip.force_encoding('UTF-8')
    raw = raw.gsub(/\n/, ' ').gsub(/\s+/, ' ')
    raw = raw.gsub(/([^{:\s])\s+([a-z0-9_]+:)/i, '\1,\2')
    raw = raw.gsub(/([a-z0-9_]+)\s*:/i, '"\1":')
    raw = raw.gsub(/:\s*([^"{\[0-9tfn].*?)\s*(?=[,}\]])/m, ': "\1"')
    raw += ' }' unless raw.end_with?('}')
    JSON.parse(raw) rescue sanitized_response3
  end

  def sanitized_response3
    raw = (self.raw_response || "{}").strip.force_encoding('UTF-8')
    raw = raw.gsub(/\n/, ' ').gsub(/\s+/, ' ')
    raw = raw.gsub(/([}\"])\s+([a-z0-9_]+)\s*:/i, '\1, "\2":')
    raw = raw.gsub(/([a-z0-9_]+)\s*:/i, '"\1":')
    raw = raw.gsub(/:\s*([^",{\[\]]+?)\s*(?=[,}\]]|$)/, ': "\1"')
    raw += ' }' unless raw.end_with?('}')
    JSON.parse(raw) rescue sanitized_response4
  end

  def sanitized_response4
    raw = (self.raw_response || "{}").strip.force_encoding('UTF-8').scrub
    raw = raw.gsub(/\n/, ' ').gsub(/\s+/, ' ')
    raw = raw.gsub(/([}\"])\s+([a-z0-9_]+)\s*:/i, '\1, "\2":')
    raw = raw.gsub(/([a-z0-9_]+)\s*:/i, '"\1":')
    raw = raw.gsub(/:\s*([^",{\[\]]+?)\s*(?=[,}\]]|$)/, ': "\1"')
    raw = raw.gsub(/,\s*([}\]])/, '\1')
    raw += ' }' unless raw.end_with?('}')
    JSON.parse(raw) rescue sanitized_response5
  end

  def sanitized_response5
    hash = {}
    self.raw_response.scan(/change_(\d+):.*?content:\s*([^,]+).*?explanation_en:\s*([^}]+)/m) do |num, cont, exp|
      hash["change_#{num}"] = { "content" => cont.strip.gsub(/\"/, ''), "explanation_en" => exp.strip.gsub(/\"/, '') }
    end
    hash["corrected_text"] = self.raw_response.match(/corrected_text:\s*([^"]+)/)[1].strip.gsub(/\"/, '')
    hash
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
    result = parsed_response.dig("#{change_keyword}#{num}", "content")
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
    parsed_response.dig("#{change_keyword}#{num}", "explanation_#{abbr}") || error_message
  end

  def assessment
    content = self.parsed_response.fetch("assessment", nil)

    # {"overall"=> "Overall, the quiz answers are..."}
    return content["overall"] if is_hash?(content) && content["overall"]

    # {"overall_accuracy"=> "The translations are mostly accurate..."}
    return content["overall_accuracy"] if is_hash?(content) && content["overall_accuracy"]

    content
  end

  def corrected_text
    # Sometimes a string is returned and sometimes it's a Hash
    content = parsed_response.fetch("corrected_text", nil)

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
end
