require "rails_helper"

# notes#update re-renders the note with Today's Notes controls only when
# the edit came from the Today's Notes list.
RSpec.describe "Note turbo update", type: :request do
  let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }
  let(:group) { Group.create!(name: "Note update #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(
      email_address: "note-update-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end
  let!(:note) { user.notes.create!(content: "Due note") }

  before { post session_path, params: { email_address: user.email_address, password: "password" } }

  it "shows the studied button when updated from Today's Notes" do
    patch note_path(note, update_from_todays_notes: true),
          params: { note: { content: "Revised" } }, headers: turbo_headers

    expect(response).to be_successful
    expect(response.body).to include(mark_note_as_studied_note_path(note))
    expect(note.reload.content).to eq("Revised")
  end

  it "shows the review controls when updated from All Notes" do
    patch note_path(note), params: { note: { content: "Revised" } }, headers: turbo_headers

    expect(response).to be_successful
    expect(response.body).not_to include(mark_note_as_studied_note_path(note))
    expect(response.body).to include("next_review_timestamp_#{note.id}")
  end
end
