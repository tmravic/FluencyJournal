class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern
  before_action :set_api_key

  private

  def current_group
    @current_group ||= Current.user&.group if Current.user
  end

  helper_method :current_group

  def set_faraday_connection(api_key)
    Faraday.new(url: 'https://api.openai.com') do |faraday|
      faraday.headers['Authorization'] = "Bearer #{api_key}"
      faraday.headers['Content-Type'] = 'application/json'
      faraday.adapter Faraday.default_adapter
    end
  end

  def set_api_key
    @api_key = Rails.application.credentials.openai[:api_key]
  end
end
