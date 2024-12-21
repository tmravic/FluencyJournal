class JournalQuery < AiQuery
  # {"change_1"=>
  #    {"content"=>"小さい針 → マイクロニードル",
  #     "explanation_en"=>"Changed '小さい針' to 'マイクロニードル' to use the correct term in Japanese."},
  #  "change_2"=>
  #    {"content"=>"太陽からの被害 → 日焼けによるダメージ",
  #     "explanation_en"=>"Changed '太陽からの被害' to '日焼けによるダメージ' to sound more natural in Japanese."},
  #  "corrected_text"=>{"text"=>"今日はシルファームという肌の施術を受けます。マイクロニードルとケミカルピーリングで何年間のニキビ跡と日焼けによるダメージを治療したいです。"}}
  #
  def parsed_response
    JSON.parse(self.raw_response)
  end

  def separate_messages
    messages = ""
    self.count_changes.times do |i|
      messages += change_content(i + 1) + "\n"
    end
    messages.strip
  end

  def count_changes
    # ["change_1", "change_2", "corrected_text"]
    parsed_response.keys.count do |key|
      key.include?('change_')
    end
  end

  def error_message
    "something went wrong"
  end

  def change_content(num)
    parsed_response.fetch("change_#{num}", error_message).fetch("content")
  end

  def change_explanation_en(num)
    parsed_response.fetch("change_#{num}", error_message).fetch("explanation_en")
  end

  def corrected_text
    # Sometimes a string is returned and sometimes it's a Hash
    content = parsed_response.fetch("corrected_text", error_message)

    #  {"text"=>"昨年のクリスマスに心をあげた"},
    #  {"text"=>"昨年のクリスマスに私はあなたに心を捧げました"}]
    return content['text'] if is_hash?(content) && content['text']

    # {"内容"=>"昨日は病院でバリウムを飲んだ後遺症に苦しんだ。"}
    return content['内容'] if is_hash?(content) && content['内容']

    #  {"Today was such a hot day."=>""}
    if is_hash?(content) && content.values.first.empty?
      return content.keys.first
    end

    #  "昨年のクリスマスに私はあなたに心を捧げました"
    content
  end

  # ["Change 1", "Change 2", "Corrected Text"]
  def titles
    parsed_response.keys.map(&:titleize)
  end

  private

  def is_hash?(content)
    content.class == Hash
  end
end
