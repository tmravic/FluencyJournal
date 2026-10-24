class PasswordsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: %i[ create update ], with: -> { redirect_to new_password_url, alert: I18n.t("session.try_again_later") }
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: t("password.reset_sent")
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      # Whoever knew the old password must sign in again with the new one.
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: t("password.reset_success"), status: :see_other
    else
      flash.now[:alert] = t("password.mismatch")
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: t("password.invalid_token")
    end
end
