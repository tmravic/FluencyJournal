# Run by spec/config/production_ssl_spec.rb with
#   RAILS_ENV=production bin/rails runner spec/support/production_ssl_probe.rb
#
# Boots the production configuration and sends requests straight through the
# Rack stack, so the SSL middleware settings are exercised as deployed. The
# result is printed as one JSON line prefixed with PROBE: (production also
# logs to STDOUT).
require "json"
require "rack/mock"

app = Rails.application

response = lambda do |url|
  status, headers, = app.call(Rack::MockRequest.env_for(url))
  {
    "status" => status,
    "location" => headers["location"] || headers["Location"],
    "hsts" => headers["strict-transport-security"] || headers["Strict-Transport-Security"]
  }
end

result = {
  "force_ssl" => app.config.force_ssl,
  "assume_ssl" => app.config.assume_ssl,
  "ssl_options_hsts" => app.config.ssl_options[:hsts]&.to_h { |k, v| [ k.to_s, v.is_a?(ActiveSupport::Duration) ? v.to_i : v ] },
  "https_up" => response.call("https://fluencyjournal.com/up"),
  "http_up" => response.call("http://fluencyjournal.com/up"),
  "http_page" => response.call("http://fluencyjournal.com/session/new"),
  "https_page" => response.call("https://fluencyjournal.com/session/new")
}

puts "PROBE:#{JSON.generate(result)}"
