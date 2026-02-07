class XAiService
  def initialize(api_key, entry_prompt, user, journal)
    @api_key = api_key
    @entry_prompt = entry_prompt
    @user = user
    @journal = journal
  end

  def call
    begin
      connection = Faraday.new(url: "https://api.x.ai")
      response = connection.post do |request|
        request.url "/v1/chat/completions"
        request.options.timeout = 120
        request.options.open_timeout = 60
        request.headers["Content-Type"] = "application/json"
        request.headers["Authorization"] = "Bearer #{@api_key}"
        request.body = {
          model: @entry_prompt.ai_model,
          response_format: { type: "json_object" },
          messages: [
            {
              role: "system",
              content: @entry_prompt.role_prompt(@user, @journal)
            },
            {
              role: "user",
              content: @entry_prompt.raw_prompt
            },
            {
              role: "user",
              content: @entry_prompt.response_format(@user)
            }
          ]
        }.to_json
      end
      return response
    rescue ::Exception => e
      Rails.logger.error("#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
    end
  end
end
