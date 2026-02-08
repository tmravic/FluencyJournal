module SanitizingHelper
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

    regex_ct = /"corrected_text":\s*(?:\{\s*)?"([^"]*)"(?:\s*\})?/
    match_corrected_text = self.raw_response.match(regex_ct)
    hash["corrected_text"] = match_corrected_text[1].strip if match_corrected_text

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
    begin
      parsed = JSON.parse(raw)
    rescue
      return sanitized_response7(string)
    end
    hash = {}
    if parsed["answers"]
      parsed["answers"].each do |num, data|
        hash["#{string}#{num}"] = data
      end
      hash.merge!(parsed.except("answers"))
    else
      hash = parsed
    end
    hash
  end

  def sanitized_response7(string)
    hash = {}
    raw = normalize_whitespace(self.raw_response)
    # Extract answers block
    answers_match = raw.match(/"answers":\s*\{(.*?)\}/m)
    return hash unless answers_match
    answers_raw = answers_match[1]
    # Regex for "N": { "content": value (possibly unquoted until next key), "explanation_en": "value" }
    regex = /"(\d+)":\s*\{\s*"content":\s*([^"]*?)\s*,\s*"explanation_en":\s*"([^"]*?)"\s*\}/m
    answers_raw.scan(regex) do |num, cont, exp|
      hash["#{string}#{num}"] = {
        "content" => cont.strip.gsub(/\\"/, '"').gsub(/「/, '').gsub(/」/, ''), # Clean Japanese brackets if needed
        "explanation_en" => exp.strip.gsub(/\\"/, '"')
      }
    end
    hash
  end

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
    # /#{Regexp.escape(string)}(\d+):.*?content:\s*([^,]+).*?explanation_en:\s*([^}]+)/m
    /"#{Regexp.escape(string)}(\d+)":\s*\{\s*"content":\s*"([^"]*)",\s*"explanation_en":\s*"([^"]*)"(?:,\s*)?\s*\}/m
  end
end