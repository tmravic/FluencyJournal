class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url

      # Why do I have this error when I log in?

      # Processing by SessionsController#create as TURBO_STREAM
      # Parameters: {"authenticity_token"=>"[FILTERED]", "email_address"=>"[FILTERED]", "password"=>"[FILTERED]", "commit"=>"Sign in"}
      # Unpermitted parameters: :authenticity_token, :commit. Context: { controller: SessionsController, action: create, request: #<ActionDispatch::Request:0x00007f136b5fdb80>, params: {"authenticity_token"=>"[FILTERED]", "email_address"=>"[FILTERED]", "password"=>"[FILTERED]", "commit"=>"Sign in", "controller"=>"sessions", "action"=>"create"} }
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
end
