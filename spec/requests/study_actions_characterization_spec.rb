require "rails_helper"

# Pins mark-as-studied and update-due-date for journals and notes before
# C8 moves the shared flow into SchedulesStudy and a controller concern.
RSpec.describe "Study actions (characterization)", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:group) { Group.create!(name: "Study char #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "study-char-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html" } }

  before { post session_path, params: { email_address: user.email_address, password: "password" } }
  after { travel_back }

  def schedule_fields(record)
    record.reload.attributes.slice("repetitions", "easiness_factor", "last_interval", "next_study_date")
  end

  it "marks a journal studied over HTML: schedule, last_studied_at, redirect and notice" do
    journal = group.journals.create!(title: "Studied over html", user: user)
    travel_to Time.zone.local(2026, 3, 10, 9, 0, 0)

    post mark_journal_as_studied_journal_path(journal)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journal_path(journal))
    expect(flash[:notice]).to eq("Journal will return on <time datetime=\"2026-03-11T00:00:00Z\" data-local=\"time\" data-format=\"%Y-%m-%d\">2026-03-11</time>")
    expect(journal.reload.last_studied_at).to eq(Time.current)
    expect(schedule_fields(journal)).to include("repetitions" => 1, "last_interval" => 1.0,
                                                "next_study_date" => 1.day.from_now)
  end

  it "marks a note studied over HTML: schedule, redirect and notice" do
    note = user.notes.create!(content: "Studied note over html")
    travel_to Time.zone.local(2026, 3, 10, 9, 0, 0)

    post mark_note_as_studied_note_path(note)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(note_path(note))
    expect(flash[:notice]).to eq("Note will return on <time datetime=\"2026-03-11T00:00:00Z\" data-local=\"time\" data-format=\"%Y-%m-%d\">2026-03-11</time>")
    expect(schedule_fields(note)).to include("repetitions" => 1, "last_interval" => 1.0,
                                             "next_study_date" => 1.day.from_now)
  end

  it "puts the turbo notice in the flash stream for a journal" do
    journal = group.journals.create!(title: "Studied over turbo", user: user)
    travel_to Time.zone.local(2026, 3, 10, 9, 0, 0)

    post mark_journal_as_studied_journal_path(journal), params: { from_all_or_todays: "all" }, headers: turbo

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Journal will return on <time datetime=\"2026-03-11T00:00:00Z\" data-local=\"time\" data-format=\"%Y-%m-%d\">2026-03-11</time>")
  end

  it "updates the due date of a journal and a note over turbo" do
    journal = group.journals.create!(title: "Due date journal", user: user)
    note = user.notes.create!(content: "Due date note")

    post update_due_date_journal_path(journal), params: { next_study_date: "2026-05-01" }, headers: turbo
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(journal.reload.next_study_date.to_date).to eq(Date.new(2026, 5, 1))

    post update_due_date_note_path(note), params: { next_study_date: "2026-05-02" }, headers: turbo
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(note.reload.next_study_date.to_date).to eq(Date.new(2026, 5, 2))
  end
end
