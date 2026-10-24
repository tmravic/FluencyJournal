# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# The policy is REPORT-ONLY: browsers log what it would have blocked in the
# console but block nothing. Review the console on every page, then remove
# the report-only line at the bottom to enforce it (see the README).
#
# What the app loads, which this policy is written around:
# - Scripts: the importmap tag and the one inline theme script in the layout
#   (both carry the nonce), and modules served from /assets. No CDN.
# - Styles: the dartsass stylesheet from /assets, the <style> Turbo adds for
#   its progress bar (it reads the nonce from the csp-nonce meta tag), and a
#   few style="" attributes in views, which a nonce cannot cover (see
#   style_src_attr below).
# - Action Cable (Turbo Streams): a websocket back to this host.
# - Text-to-speech: audio fetched from this host and played from a blob: URL.
# - Images and fonts: the app's own files (and data: URIs). No external hosts.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data
    policy.media_src   :self, :blob
    policy.object_src  :none
    policy.base_uri    :self
    policy.form_action :self
    policy.script_src  :self
    policy.style_src   :self
    # Inline style="" attributes are not covered by a nonce. Allowing them
    # here keeps the report quiet about them; removing the attributes and then
    # this line is a separate, later clean-up.
    policy.style_src_attr :unsafe_inline
    # 'self' covers the websocket in current browsers; wss: (and ws: outside
    # production, where there is no TLS) covers the older ones.
    policy.connect_src :self, :wss, *(Rails.env.production? ? [] : [ :ws ])
    # Specify URI for violation reports. Without it, violations are only
    # logged in the browser console.
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate session nonces for permitted importmap, inline scripts, and inline styles.
  # A request that has no session yet (the first visit, the sign-in page) has
  # no session id, which would make an empty nonce that matches nothing, so
  # it gets a random one instead.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s.presence || SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]

  # Report violations without enforcing the policy. Remove this line (or set
  # it to false) to enforce.
  config.content_security_policy_report_only = true
end
