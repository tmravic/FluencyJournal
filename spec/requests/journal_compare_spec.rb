require "rails_helper"

# Characterization of GET /journals/:id/compare (query building and the
# cancel branch), written before the queries became scopes (C16).
RSpec.describe "GET /journals/:id/compare", type: :request do
  let(:group) { Group.create!(name: "Compare #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "compare-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let!(:current) { journal("Current", due: false) }
  let!(:zebra) { journal("Zebra", due: true) }
  let!(:apple) { journal("Apple", due: false) }
  let!(:mango) { journal("Mango", due: true) }

  def journal(title, due:)
    Journal.create!(title: title, user: user, group: group, last_interval: 1,
                    next_study_date: due ? 1.day.ago : 5.days.from_now).tap do |journal|
      journal.entries.create!(content: "#{title}の本文")
    end
  end

  before { post session_path, params: { email_address: user.email_address, password: "password" } }

  def option_titles(body)
    body[/<select.*?<\/select>/m].scan(/<option[^>]*>(.*?)<\/option>/).flatten
  end

  it "lists the other journals alphabetically and compares nothing by default" do
    get compare_journal_path(current)

    expect(response).to have_http_status(:ok)
    expect(option_titles(response.body)).to eq(%w[Apple Mango Zebra])
    expect(response.body).not_to include("の本文")
  end

  it "lists only due journals alphabetically with the todays filter" do
    get compare_journal_path(current, todays: true)

    expect(option_titles(response.body)).to eq(%w[Mango Zebra])
  end

  it "shows the selected journals' entries, ignoring blank ids" do
    get compare_journal_path(current, journal_ids: [ "", zebra.id.to_s, apple.id.to_s ])

    expect(response.body.index("Appleの本文")).to be < response.body.index("Zebraの本文")
    expect(response.body).not_to include("Mangoの本文")
  end

  it "does not show journals of another group" do
    other_group = Group.create!(name: "Other #{SecureRandom.hex(4)}")
    other_user = User.create!(email_address: "other-#{SecureRandom.hex(4)}@example.com", password: "password",
                              original_language: "English", learning_language: "Japanese", group: other_group)
    outsider = Journal.create!(title: "Outsider", user: other_user, group: other_group, last_interval: 1)
    outsider.entries.create!(content: "外の本文")

    get compare_journal_path(current, journal_ids: [ outsider.id.to_s ])

    expect(option_titles(response.body)).not_to include("Outsider")
    expect(response.body).not_to include("外の本文")
  end

  it "loads the entries of all compared journals with one query" do
    entry_queries = []
    counter = lambda do |*, payload|
      entry_queries << payload[:sql] if payload[:sql].match?(/FROM "entries"/)
    end

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get compare_journal_path(current, journal_ids: [ zebra.id.to_s, apple.id.to_s, mango.id.to_s ])
    end

    expect(response.body).to include("Zebraの本文", "Appleの本文", "Mangoの本文")
    expect(entry_queries.size).to eq(1)
  end

  it "answers only the empty compare frame on cancel" do
    get compare_journal_path(current, cancel: true)

    expect(response.body).to eq(%(<turbo-frame id="compare"></turbo-frame>))
  end

  it "is 404 for a journal outside the group" do
    other_group = Group.create!(name: "Other #{SecureRandom.hex(4)}")
    other_user = User.create!(email_address: "other2-#{SecureRandom.hex(4)}@example.com", password: "password",
                              original_language: "English", learning_language: "Japanese", group: other_group)
    outsider = Journal.create!(title: "Outsider", user: other_user, group: other_group, last_interval: 1)

    get compare_journal_path(outsider)

    expect(response).to have_http_status(:not_found)
  end
end
