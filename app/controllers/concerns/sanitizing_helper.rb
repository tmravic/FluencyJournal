#TODO: This is too much, I need to look at all the responses elyza has given me so far
# and catch all the different versions of the response data that could come out
# and account for the different variations.
# Prompt.where(ai_model: "elyza_llm").count
module SanitizingHelper
  def sanitized_response
    raw = prepare_raw
    raw = normalize_whitespace(raw)
    raw = substitute_alphanumeric(raw)
    raw = add_closing_brace(raw)
    JSON.parse(raw) rescue sanitized_response2
  end

  def sanitized_response2
    raw = prepare_raw(options: {encode: true})
    raw = normalize_whitespace(raw)
    raw = add_commas_variant1(raw)
    raw = substitute_alphanumeric(raw)
    raw = quote_values_variant1(raw)
    raw = add_closing_brace(raw)
    JSON.parse(raw) rescue sanitized_response3
  end

  def sanitized_response3
    raw = prepare_raw(options: {encode: true})
    raw = normalize_whitespace(raw)
    raw = add_commas_variant2(raw)
    raw = substitute_alphanumeric(raw)
    raw = quote_values_variant2(raw)
    raw = add_closing_brace(raw)
    JSON.parse(raw) rescue sanitized_response4
  end

  def sanitized_response4
    raw = prepare_raw(options: {encode: true, scrub: true})
    raw = normalize_whitespace(raw)
    raw = add_commas_variant2(raw)
    raw = substitute_alphanumeric(raw)
    raw = quote_values_variant2(raw)
    raw = remove_trailing_commas(raw)
    raw = add_closing_brace(raw)
    JSON.parse(raw) rescue sanitized_response5
  end

  def sanitized_response5
    @api_key = Rails.application.credentials.xai[:api_key]
    response = RescueBadFormatJob.perform_now(@api_key, self)
    return response
    #TODO: Should probably overwrite save the raw_response with what this returns
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