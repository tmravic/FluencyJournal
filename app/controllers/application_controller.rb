class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  around_action :switch_locale
  before_action :set_api_key
  helper_method :current_group

  private

  # This runs around every single request and safely sets the locale
  # for that request only (and restores it afterwards)
  def switch_locale(&action)
    # 1. Allow manual override in URL: ?locale=ja or ?locale=en
    # 2. Otherwise read the browser's Accept-Language header
    # 3. Fall back to default (:en)
    locale = params[:locale].presence ||
             extract_locale_from_accept_language_header ||
             I18n.default_locale

    I18n.with_locale(locale, &action)
  end

  def current_group
    @current_group ||= Current.user&.group if Current.user
  end

  def extract_locale_from_accept_language_header
    return nil if request.env['HTTP_ACCEPT_LANGUAGE'].blank?

    # Picks the first language the browser prefers that we actually support (ja or en)
    request.env['HTTP_ACCEPT_LANGUAGE'].scan(/[a-z]{2}/).find do |code|
      I18n.available_locales.include?(code.to_sym)
    end&.to_sym
  end

  def set_api_key
    @api_key = Rails.application.credentials.xai[:api_key]
  end
end
