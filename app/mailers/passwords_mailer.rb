class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: t("password.mailer_subject"), to: user.email_address
  end
end
