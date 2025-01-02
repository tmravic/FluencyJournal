class PagesController < ApplicationController
  require 'securerandom'
  before_action :set_api_key
  before_action :get_ai_models

  def home
  end
end
