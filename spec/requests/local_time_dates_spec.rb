require "rails_helper"

RSpec.describe "Local time dates", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user
    group = Group.create!(name: "Dates #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "dates-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def turbo_stream_headers
    { "Accept" => "text/vnd.turbo-stream.html" }
  end

  it "renders written dates and the next review in the browser's zone" do
    user = create_user
    written_on = Time.zone.local(2024, 3, 2, 8, 0, 0)
    reviews_on = Time.zone.local(2026, 12, 1, 9, 30, 0)
    journal = user.group.journals.create!(title: "Dated", user: user, next_study_date: reviews_on)
    journal.update_columns(created_at: written_on)
    entry = journal.entries.create!(content: "A line")
    entry.update_columns(created_at: written_on)
    sign_in(user)

    get journal_path(journal, locale: "ja")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('lang="ja"')
    expect(response.body).to include('data-local-time-today="今日"')
    expect(response.body).to include('data-local-time-yesterday="昨日"')
    expect(response.body).to include('data-local-time-tomorrow="明日"')
    expect(response.body).to include('data-local="weekday-or-date"')
    expect(response.body).to include(%(datetime="#{reviews_on.utc.xmlschema}"))
    expect(response.body).to include('data-format="%Y-%m-%d"')
    expect(response.body).to include(%(datetime="#{written_on.utc.xmlschema}")).twice
    expect(response.body).not_to include("2024-03-02")
  end

  it "puts the return day in the mark-studied notice without a month/day/year string" do
    user = create_user
    journal = user.group.journals.create!(title: "Studied", user: user, last_interval: 1)
    note = user.notes.create!(content: "Studied note", last_interval: 1)
    sign_in(user)

    post mark_journal_as_studied_journal_path(journal),
         params: { from_all_or_todays: "todays" },
         headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Journal will return on")
    expect(response.body).to include('data-local="time"')
    expect(response.body).to include('data-format="%Y-%m-%d"')
    expect(response.body).not_to match(%r{\d{2}/\d{2}/\d{4}})

    post mark_note_as_studied_note_path(note), headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Note will return on")
    expect(response.body).to include('data-local="time"')
    expect(response.body).not_to match(%r{\d{2}/\d{2}/\d{4}})
  end
end
