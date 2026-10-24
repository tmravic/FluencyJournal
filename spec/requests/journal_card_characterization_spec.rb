require "rails_helper"
require_relative "../support/characterization_snapshot"

# Pins the journal card (journals/_journal) as the Today's and All journals
# pages and the editor's own update response render it. (The broadcast cards
# are covered by journal_card_broadcast_spec.rb.)
RSpec.describe "Journal card (characterization)", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  snapshot = CharacterizationSnapshot.new("journal_card")

  around do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    travel_to(Time.zone.local(2026, 3, 10, 9, 0, 0)) { example.run }
  ensure
    ActiveJob::Base.queue_adapter = original
  end

  let(:group) { Group.create!(name: "Card #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "card-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let!(:journal) do
    Journal.create!(title: "Card journal", user: user, group: group, last_interval: 1,
                    next_study_date: Time.zone.local(2026, 3, 10, 8, 0, 0))
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def card_in(html, record)
    html[%r{<turbo-frame id="journal_#{record.id}".*?</turbo-frame>}m].to_s.gsub(record.id.to_s, "JID")
  end

  it "renders the card on Today's journals with the studied button" do
    sign_in(user)
    get journals_path
    card = card_in(response.body, journal)
    snapshot.match(self, "page/todays", { "card" => card.lines.map(&:rstrip).reject(&:empty?) })
    expect(card).to include("mark_journal_as_studied")
  end

  it "renders the card on All journals with the next review date" do
    sign_in(user)
    get all_journals_path
    card = card_in(response.body, journal)
    snapshot.match(self, "page/all", { "card" => card.lines.map(&:rstrip).reject(&:empty?) })
    expect(card).to include(I18n.t("note.next_review"))
  end

  it "renders the card the editor gets back from a Turbo Stream update" do
    sign_in(user)
    patch journal_path(journal), params: { journal: { title: "Edited", from_all_or_todays: "todays" } },
                                 headers: { "Accept" => "text/vnd.turbo-stream.html" }
    card = card_in(response.body, journal)
    snapshot.match(self, "editor/update", { "status" => response.status, "card" => card.lines.map(&:rstrip).reject(&:empty?) })
    expect(response).to have_http_status(:ok)
  end
end
