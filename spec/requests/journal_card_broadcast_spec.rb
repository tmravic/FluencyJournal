require "rails_helper"

# Journal cards pushed to the group must be the card the receiving page would
# render for itself: the Today's page and the All page get their own stream.
RSpec.describe "Journal card broadcasts", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    travel_to(Time.zone.local(2026, 3, 10, 9, 0, 0)) { example.run }
  ensure
    ActiveJob::Base.queue_adapter = original
  end

  let(:group) { Group.create!(name: "Cast #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "cast-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:due) { Time.zone.local(2026, 3, 10, 8, 0, 0) }
  let!(:journal) { Journal.create!(title: "Cast", user: user, group: group, last_interval: 1, next_study_date: due) }

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def stream_name(mode)
    Turbo::StreamsChannel.send(:stream_name_from, Journal.card_stream(group, mode))
  end

  def sent_to(mode)
    ActionCable.server.pubsub.broadcasts(stream_name(mode)).map do |message|
      message.is_a?(String) && message.start_with?('"') ? JSON.parse(message) : message
    end
  end

  def clear_broadcasts
    %i[todays all].each { |mode| ActionCable.server.pubsub.clear_messages(stream_name(mode)) }
    ActionCable.server.pubsub.clear_messages(Turbo::StreamsChannel.send(:stream_name_from, [ group, "journals" ]))
  end

  def card(html, record)
    html[%r{<turbo-frame id="journal_#{record.id}".*?</turbo-frame>}m].to_s
  end

  def page_card(path, record)
    sign_in(user)
    get path
    card(response.body, record)
  end

  def action_of(html)
    html[/action="(\w+)"/, 1]
  end

  # The journal above queued its own create broadcast.
  before do
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    clear_broadcasts
  end

  it "sends the Today's page the card that page renders, and the All page its own" do
    todays_page = page_card(journals_path, journal)
    all_page = page_card(all_journals_path, journal)
    expect(todays_page).to include("mark_journal_as_studied")
    expect(all_page).to include(I18n.t("note.next_review"))

    journal.update!(title: "Renamed")
    perform_enqueued_jobs
    journal.reload

    todays_page = page_card(journals_path, journal)
    all_page = page_card(all_journals_path, journal)
    todays_sent, all_sent = sent_to(:todays), sent_to(:all)

    expect(todays_sent.map { |html| action_of(html) }).to eq([ "replace" ])
    expect(all_sent.map { |html| action_of(html) }).to eq([ "replace" ])
    expect(card(todays_sent.first, journal)).to eq(todays_page)
    expect(card(all_sent.first, journal)).to eq(all_page)
    expect(card(todays_sent.first, journal)).to include("mark_journal_as_studied")
    expect(card(all_sent.first, journal)).not_to include("mark_journal_as_studied")
  end

  it "appends a new journal's card to both pages in each page's own form" do
    created = Journal.create!(title: "Created", user: user, group: group, last_interval: 1, next_study_date: due)
    perform_enqueued_jobs

    expect(sent_to(:todays).map { |html| action_of(html) }).to eq([ "append" ])
    expect(sent_to(:all).map { |html| action_of(html) }).to eq([ "append" ])
    expect(card(sent_to(:todays).first, created)).to eq(page_card(journals_path, created))
    expect(card(sent_to(:all).first, created)).to eq(page_card(all_journals_path, created))
  end

  it "takes a journal that stopped being due off the Today's page and keeps it on the All page" do
    journal.update!(next_study_date: Time.zone.local(2026, 3, 20, 8, 0, 0))
    perform_enqueued_jobs

    expect(sent_to(:todays).map { |html| action_of(html) }).to eq([ "remove" ])
    expect(sent_to(:all).map { |html| action_of(html) }).to eq([ "replace" ])
  end

  it "does not add a journal that is not due to the Today's page" do
    Journal.create!(title: "Later", user: user, group: group, last_interval: 1,
                    next_study_date: Time.zone.local(2026, 3, 20, 8, 0, 0))
    perform_enqueued_jobs

    expect(sent_to(:todays)).to be_empty
    expect(sent_to(:all).map { |html| action_of(html) }).to eq([ "append" ])
  end

  it "removes the card from both pages when the journal is destroyed" do
    journal.destroy!

    expect(sent_to(:todays).map { |html| action_of(html) }).to eq([ "remove" ])
    expect(sent_to(:all).map { |html| action_of(html) }).to eq([ "remove" ])
  end

  it "no longer broadcasts to the shared group stream with the degraded card" do
    journal.update!(title: "Renamed")
    perform_enqueued_jobs

    shared = Turbo::StreamsChannel.send(:stream_name_from, [ group, "journals" ])
    expect(ActionCable.server.pubsub.broadcasts(shared)).to be_empty
  end

  describe "page subscriptions" do
    def subscribed_stream(html)
      tag = html[/<turbo-cable-stream-source[^>]*id="journals_stream_source"[^>]*>/] ||
            html[/<turbo-cable-stream-source[^>]*>/]
      signed = tag[/signed-stream-name="([^"]*)"/, 1]
      Turbo.signed_stream_verifier.verified(signed)
    end

    it "subscribes Today's journals to the todays stream and All journals to the all stream" do
      sign_in(user)

      get journals_path
      expect(response.body).to include('id="journals_stream_source"')
      expect(subscribed_stream(response.body)).to eq(stream_name(:todays))

      get all_journals_path
      expect(response.body).to include('id="journals_stream_source"')
      expect(subscribed_stream(response.body)).to eq(stream_name(:all))
    end

    it "moves the subscription when the page is switched with a Turbo Stream" do
      sign_in(user)
      turbo = { "Accept" => "text/vnd.turbo-stream.html" }

      get all_journals_path, headers: turbo
      expect(response.body).to include('target="journals_stream_source"')
      expect(subscribed_stream(response.body)).to eq(stream_name(:all))

      get journals_path, headers: turbo
      expect(response.body).to include('target="journals_stream_source"')
      expect(subscribed_stream(response.body)).to eq(stream_name(:todays))
    end
  end
end
