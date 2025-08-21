class UpController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :set_api_key

  def index
    head :ok
  end

  def databases
    ActiveRecord::Base.connection.execute("SELECT 1")

    head :ok
  end
end
