class PagesController < ApplicationController
  require 'securerandom'
  before_action :set_api_key
  before_action :get_ai_models

  def home
    # This uuid is used to create a unique turbo stream for whomever is on this webpage
    @uuid = SecureRandom.uuid
  end

  def ai_request
    AiRequestJob.perform_later(ai_request_params, @api_key)
  end

  private

  def ai_request_params
    params.require(:ai_request).permit(:prompt, :ai_model, :uuid)
  end

  def get_ai_models
    @ai_models = list_models(@api_key).map { |ai_model| ai_model['id'] }
  end

  def list_models(api_key)
    connection = set_faraday_connection(api_key)
    response = connection.get('/v1/models')

    if response.success?
      JSON.parse(response.body)["data"]
    else
      puts "Error: #{response.status} - #{response.body}"
    end
  end

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
