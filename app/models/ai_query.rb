class AiQuery < ApplicationRecord
  LANGUAGE_ABBREVIATIONS = { "English" => "en", "Japanese" => "jp" }

  belongs_to :journal, optional: true
  belongs_to :prompt
  delegate :user, to: :journal, allow_nil: true
  has_many :ai_outputs, dependent: :nullify

  has_and_belongs_to_many :followups
  # has_one :ai_queries_followup, dependent: :nullify
  # has_one :followup, through: :ai_queries_followup, dependent: :nullify

  validates :prompt_tokens, :completion_tokens, :total_tokens, numericality: { only_integer: true }
  validates :raw_response, presence: true

  after_destroy -> {
    prompt.destroy!
  }

  def abbr(user)
    # This same thing exists on Prompt
    LANGUAGE_ABBREVIATIONS.fetch(user.original_language, 'English')
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
    JSON.parse(self.raw_response || '{}') rescue {}
  end

  def count_changes(string)
    # ["change_1", "change_2", "corrected_text"]
    parsed_response.keys.count do |key|
      key.include?(string)
    end
  end

  def error_message
    "something went wrong"
  end

  def change_content(num, change_keyword)
    result = parsed_response.dig("#{change_keyword}#{num}", "content")
    if result
      if result.include?('→')
        return result.split('→')
      else
        return result
      end
    end

    error_message
  end

  def change_explanation(change_keyword, num, abbr)
    parsed_response.dig("#{change_keyword}#{num}","explanation_#{abbr}") || error_message
  end

  def corrected_text
    # Sometimes a string is returned and sometimes it's a Hash
    content = parsed_response.fetch('corrected_text', nil)

    # When the user input nothing
    # {"..."=>0}
    return "No content" if is_hash?(content) && content['...']

    # {"お時間がかかってしまい申し訳ございません。"=>"お時間がかかってしまい申し訳ございません。"}
    return content.keys.first if is_hash?(content) && content.keys.first == content.values.first

    #  {"text"=>"昨年のクリスマスに心をあげた"},
    #  {"text"=>"昨年のクリスマスに私はあなたに心を捧げました"}]
    return content['text'] if is_hash?(content) && content['text']

    # {"内容"=>"昨日は病院でバリウムを飲んだ後遺症に苦しんだ。"}
    return content['内容'] if is_hash?(content) && content['内容']

    # {"内容"=>"昨日は病院でバリウムを飲んだ後遺症に苦しんだ。"}
    return content['content'] if is_hash?(content) && content['content']

    # {"corrected_japanese"=>"昨日は病院でバリウムを飲んだ後遺症に苦しんだ。"}
    return content['corrected_japanese'] if is_hash?(content) && content['corrected_japanese']

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
