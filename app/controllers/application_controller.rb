class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern
  before_action :set_api_key

  def list_models(api_key)
    connection = set_faraday_connection(api_key)
    response = connection.get("/v1/models")

    if response.success?
      JSON.parse(response.body)["data"]
    else
      puts "Error: #{response.status} - #{response.body}"
    end
  end

  def get_ai_models
    @ai_models = list_models(@api_key).map { |ai_model| ai_model["id"] }
  end

  private

  def current_group
    @current_group ||= Current.user&.group if Current.user
  end

  helper_method :current_group

  def set_faraday_connection(api_key)
    Faraday.new(url: "https://api.x.ai") do |faraday|
      faraday.headers["Authorization"] = "Bearer #{api_key}"
      faraday.headers["Content-Type"] = "application/json"
      faraday.adapter Faraday.default_adapter
    end
  end

  def set_api_key
    @api_key = Rails.application.credentials.xai[:api_key]
  end
end
