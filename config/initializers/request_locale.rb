# Picks en or ja the same way ApplicationController does: ?locale=, then
# Accept-Language, then the default. It wraps ShowExceptions so a rescued
# error page still sees that locale. PublicExceptions reads I18n.locale
# when it chooses public/404.ja.html over public/404.html, and the
# controller's around_action has already restored the default by then.
module RequestLocale
  module_function

  def from_env(env)
    from_query(env["QUERY_STRING"]) ||
      from_accept_language(env["HTTP_ACCEPT_LANGUAGE"]) ||
      I18n.default_locale
  end

  def from_query(query)
    value = Rack::Utils.parse_query(query.to_s)["locale"]
    value.to_s.presence_in(I18n.available_locales.map(&:to_s))&.to_sym
  end

  def from_accept_language(header)
    return if header.blank?

    header.scan(/[a-z]{2}/).find { |code| I18n.available_locales.include?(code.to_sym) }&.to_sym
  end

  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      I18n.with_locale(RequestLocale.from_env(env)) { @app.call(env) }
    end
  end
end

Rails.application.config.middleware.insert_before ActionDispatch::ShowExceptions, RequestLocale::Middleware
