require "rails_helper"

RSpec.describe "POST /notes draft create", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user
    group = Group.create!(name: "Draft create #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "draft-create-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  it "inserts the new draft after the draft note, not after the vocab note" do
    user = create_user
    now = Time.current
    draft = user.notes.create!(
      content: "Existing draft",
      category: :draft_journal,
      last_interval: 1,
      next_study_date: now - 1.day
    )
    vocab = user.notes.create!(
      content: "Closer vocab",
      category: :vocab,
      last_interval: 1,
      next_study_date: now - 1.hour
    )
    sign_in(user)

    post notes_path,
         params: {
           view_context: "draft_notes",
           note: { content: "Fresh draft", category: "draft_journal" }
         },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include(%(action="after"))
    expect(response.body).to include(%(target="note_#{draft.id}"))
    expect(response.body).not_to include(%(target="note_#{vocab.id}"))
    expect(response.body).not_to include(%(action="prepend" target="notes"))
    expect(response.body).to include(%(target="note_header"))
    expect(response.body).to include(I18n.t("note.draft_journals"))
    expect(response.body).to include("view_context=draft_notes")
  end
end
