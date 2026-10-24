# Recovers the readable text from whatever JSON value the model returned
# for a field that should have been a sentence.
#
# Strings are stripped, arrays and objects are searched recursively, and
# repeated lines are dropped. When the model puts the sentence in an object's
# KEY (for example {"今日は雨だった。" => ""}) and nothing readable is in the
# value, the key is used. Anything else (numbers, nil, true) has no text.
module Prose
  module_function

  # The text inside value, or nil when there is none.
  def from(value)
    case value
    when String
      value.strip.presence
    when Array
      value.filter_map { |item| from(item) }.uniq.join("\n").presence
    when Hash
      value.flat_map { |key, item| from_entry(key, item) }.uniq.join("\n").presence
    end
  end

  # A key that reads like a sentence: it has kana, kanji or a space, and is
  # not a bare identifier such as "text" or "line_1".
  def sentence_key?(key)
    return false unless key.is_a?(String)

    text = key.strip
    return false if text.blank? || text.match?(/\A\w+\z/)

    text.match?(/\p{Hiragana}|\p{Katakana}|\p{Han}/) || text.include?(" ")
  end

  def from_entry(key, item)
    text = from(item)
    if text
      [ text ]
    elsif sentence_key?(key)
      [ key.strip ]
    else
      []
    end
  end
  private_class_method :from_entry
end
