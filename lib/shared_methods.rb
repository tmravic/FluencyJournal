module SharedMethods
  def convert_hash_to_string_with_line_breaks(content)
    # {
    #   "reading"=>"(honnei no yoru ni shite)",
    #   "English_example_sentence"=>"In the span of just one night;",
    #   "Japanese_example_sentence"=>"ほとんど一夜にして"
    # }
    content.each_with_object("") do |(key, value), str|
      str << "#{key}: #{value}\n"
    end.chomp
    # "reading: (honnei no yoru ni shite)\nEnglish_example_sentence: In the span of just one night;
    # \nJapanese_example_sentence: ほとんど一夜にして"
  end
end