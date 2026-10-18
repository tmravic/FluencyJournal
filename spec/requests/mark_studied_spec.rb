require "rails_helper"

RSpec.describe "Mark studied", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user
    group = Group.create!(name: "Study group #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "studied-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def turbo_stream_headers
    { "Accept" => "text/vnd.turbo-stream.html" }
  end

  describe "POST /journals/:id/mark_journal_as_studied" do
    it "drops the journal from today's list and shows the empty state when nothing else is due" do
      user = create_user
      journal = user.group.journals.create!(title: "Only due", user: user)
      sign_in(user)

      post mark_journal_as_studied_journal_path(journal),
           params: { from_all_or_todays: "todays" },
           headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(action="remove"))
      expect(response.body).to include(%(target="journal_#{journal.id}"))
      expect(response.body).to include(%(target="new_journal"))
      expect(response.body).to include("journals due today")
      expect(response.body).to include(I18n.t("journal.due_today_count", count: 0))
      expect(response.body).not_to include(%(target="journals"))
      expect(response.body).not_to include('action="after"')
      expect(response.body.scan(/action="prepend" target="([^"]+)"/).flatten).to eq([ "flash" ])
      expect(user.group.journals.next_to_study).not_to include(journal)
    end

    it "leaves the other due journals in place" do
      user = create_user
      studied = user.group.journals.create!(title: "Studied today", user: user)
      still_due = user.group.journals.create!(title: "Still due", user: user, next_study_date: 1.hour.ago)
      sign_in(user)

      post mark_journal_as_studied_journal_path(studied),
           params: { from_all_or_todays: "todays" },
           headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(action="remove"))
      expect(response.body).to include(%(target="journal_#{studied.id}"))
      expect(response.body).not_to include('action="after"')
      expect(response.body.scan(/action="prepend" target="([^"]+)"/).flatten).to eq([ "flash" ])
      expect(response.body).not_to include("journals due today")
      expect(response.body).to include(I18n.t("journal.due_today_count", count: 1))
      expect(user.group.journals.next_to_study).to contain_exactly(still_due)
    end

    it "does not remove the journal or swap in today's empty state on All Journals" do
      user = create_user
      journal = user.group.journals.create!(title: "Stays on all", user: user)
      sign_in(user)

      post mark_journal_as_studied_journal_path(journal),
           params: { from_all_or_todays: "all" },
           headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('action="remove"')
      expect(response.body).not_to include("journals due today")
      expect(response.body).not_to include(%(target="journals"))
      expect(response.body).to include(%(target="next_review_timestamp"))
      expect(response.body).to include(%(target="mark_studied_button"))
      expect(response.body).to include(I18n.t("journal.due_today_count", count: 0))
      expect(user.group.journals.next_to_study).not_to include(journal)
    end
  end

  describe "POST /notes/:id/mark_note_as_studied" do
    it "drops the note from today's list and shows the empty state when nothing else is due" do
      user = create_user
      note = user.notes.create!(content: "Only due note")
      sign_in(user)

      post mark_note_as_studied_note_path(note), headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(action="remove"))
      expect(response.body).to include(%(target="note_#{note.id}"))
      expect(response.body).to include(%(target="new_note"))
      expect(response.body).to include(%(target="note_header"))
      expect(response.body).to include("notes due today")
      expect(response.body).to include(I18n.t("note.due_today_count", count: 0))
      expect(response.body).not_to include(%(target="notes"))
      expect(response.body).not_to include('action="after"')
      expect(response.body.scan(/action="prepend" target="([^"]+)"/).flatten).to eq([ "flash" ])
      expect(user.notes.next_to_study).not_to include(note)
    end

    it "leaves the other due notes in place" do
      user = create_user
      studied = user.notes.create!(content: "Studied note")
      still_due = user.notes.create!(content: "Still due note", next_study_date: 1.hour.ago)
      sign_in(user)

      post mark_note_as_studied_note_path(studied), headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(action="remove"))
      expect(response.body).not_to include('action="after"')
      expect(response.body.scan(/action="prepend" target="([^"]+)"/).flatten).to eq([ "flash" ])
      expect(response.body).not_to include("notes due today")
      expect(response.body).to include(I18n.t("note.due_today_count", count: 1))
      expect(user.notes.next_to_study).to contain_exactly(still_due)
    end
  end
end
