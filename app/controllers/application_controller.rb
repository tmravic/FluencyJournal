class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  around_action :switch_locale
  helper_method :current_group

  private

  # This runs around every single request and safely sets the locale
  # for that request only (and restores it afterwards)
  def switch_locale(&action)
    # Same rules as RequestLocale::Middleware, which also wraps the
    # error pages. ?locale= wins, then Accept-Language, then the default.
    I18n.with_locale(RequestLocale.from_env(request.env), &action)
  end

  def current_group
    @current_group ||= Current.user&.group if Current.user
  end

  # "1", "true", "on" etc. become true; anything else (including a missing key) is false.
  def boolean_param(key)
    ActiveModel::Type::Boolean.new.cast(params[key]) || false
  end
end
