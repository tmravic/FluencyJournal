class XAiTtsService
  # Language codes live on Prompt::LANGUAGE_ABBREVIATIONS. Callers pass
  # "auto" when the learning language is not in that map.
  DEFAULT_VOICE = "ara"

  class TtsError < StandardError; end

  def initialize(attributes = {})
    @api_key = attributes[:api_key]
    @text = attributes[:text]
    @language = attributes[:language] || "auto"
    @voice_id = attributes[:voice_id] || DEFAULT_VOICE
  end

  def call
    response = connection.post do |request|
      request.url "/v1/tts"
      request.options.timeout = 120
      request.options.open_timeout = 60
      request.headers["Content-Type"] = "application/json"
      request.headers["Authorization"] = "Bearer #{@api_key}"
      request.body = {
        text: @text,
        voice_id: @voice_id,
        language: @language
      }.to_json
    end

    raise TtsError, response.body unless response.success?

    response.body
  end

  private

  def connection
    Faraday.new(url: "https://api.x.ai")
  end
end