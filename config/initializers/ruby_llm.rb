RubyLLM.configure do |config|
  config.xai_api_key = Rails.application.credentials.dig(:xai, :api_key)
  config.request_timeout = 120
  # Chat completions sends role "developer" unless this is set. These prompts
  # are system messages, on xAI as well as OpenAI.
  config.openai_use_system_role = true
end
