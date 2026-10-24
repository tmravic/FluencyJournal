require "rails_helper"

# The policy only reports (it blocks nothing yet), so the pages must keep
# rendering exactly as before and every inline script must carry the nonce
# the header names. When the policy is enforced, an inline script without the
# nonce is the thing that would break.
RSpec.describe "Content security policy", type: :request do
  let(:group) { Group.create!(name: "CSP #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "csp-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:journal) { Journal.create!(title: "CSP journal", user: user, group: group, last_interval: 1) }

  def sign_in
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def policy
    response.headers["Content-Security-Policy-Report-Only"]
  end

  def directive(name)
    policy.split(";").map(&:strip).find { |part| part.start_with?("#{name} ") }
  end

  it "is delivered as report-only, never as an enforced header" do
    get new_session_path

    expect(response).to have_http_status(:ok)
    expect(policy).to be_present
    expect(response.headers["Content-Security-Policy"]).to be_nil
  end

  it "covers what the app loads and allows no outside hosts" do
    get new_session_path

    expect(directive("default-src")).to eq("default-src 'self'")
    expect(directive("script-src")).to match(/\Ascript-src 'self' 'nonce-[^']+'\z/)
    expect(directive("style-src")).to match(/\Astyle-src 'self' 'nonce-[^']+'\z/)
    expect(directive("connect-src")).to include("'self'").and include("wss:")
    expect(directive("media-src")).to include("blob:")
    expect(directive("object-src")).to eq("object-src 'none'")
    expect(policy).not_to match(%r{https?://|\bhttps:|\*})
  end

  it "gives a request with no session a real nonce, not an empty one" do
    get new_session_path

    nonce = directive("script-src")[/'nonce-([^']+)'/, 1]
    expect(nonce).to be_present
    expect(response.body).to include(%(<script nonce="#{nonce}">))
    expect(response.body).to include(%(<meta name="csp-nonce" content="#{nonce}"))
  end

  it "uses one nonce for the header, the meta tag, the importmap and the inline theme script" do
    sign_in
    get journals_path

    expect(response).to have_http_status(:ok)
    nonce = directive("script-src")[/'nonce-([^']+)'/, 1]
    expect(nonce).to be_present
    expect(response.body).to include(%(<meta name="csp-nonce" content="#{nonce}"))
    expect(response.body).to match(/<script type="importmap"[^>]*nonce="#{Regexp.escape(nonce)}"/)
    expect(response.body).to include(%(<script nonce="#{nonce}">))
    expect(response.body).to include("localStorage.getItem(\"theme\")")
  end

  it "leaves no inline script without a nonce on the main pages" do
    sign_in
    journal.entries.create!(content: "文。")
    note = user.notes.create!(content: "Note")

    [ journals_path, all_journals_path, journal_path(journal), notes_path, note_path(note), new_session_path ].each do |path|
      get path
      expect(response).to have_http_status(:ok), "#{path} -> #{response.status}"
      bare = response.body.scan(/<script(?![^>]*\bsrc=)(?![^>]*nonce=)[^>]*>/)
      expect(bare).to eq([]), "#{path} has an inline script without a nonce"
    end
  end
end
