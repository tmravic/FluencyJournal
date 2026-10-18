require "rails_helper"

RSpec.describe "followup history chips", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user
    group = Group.create!(name: "Followup history #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "followup-history-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def create_prompt(type:)
    Prompt.create!(
      type: type,
      raw_prompt: "prompt",
      sent_role_prompt: "role",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      base_content: "question",
      user_generated_content: "reference"
    )
  end

  it "links the followup chip through the prompt and the correction chip through the query" do
    user = create_user
    journal = Journal.create!(title: "History", user: user, group: user.group, last_interval: 1)
    entry = journal.entries.create!(content: "一行")

    followup_prompt = create_prompt(type: "FreeQuestionPrompt")
    followup = Followup.create!(origin: entry, prompt: followup_prompt, source_tag: "ai_assistant")
    AiQuery.create!(raw_response: "{}", prompt: followup_prompt, journal: journal)

    correction_prompt = create_prompt(type: "EntryPrompt")
    correction = AiQuery.create!(raw_response: "{}", prompt: correction_prompt, journal: journal)

    sign_in(user)
    get journal_path(journal)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(followup_path(followup, source_tag: "ai_assistant"))
    expect(response.body).to include(journal_ai_query_path(journal, correction))
    expect(response.body).not_to include(followup_path(followup, source_tag: "notes_box"))
  end

  it "shows a note's followup chip from the origin link" do
    user = create_user
    note = user.notes.create!(content: "覚悟", next_study_date: Time.current)
    followup = Followup.create!(
      origin: note,
      prompt: create_prompt(type: "FreeQuestionPrompt"),
      source_tag: "notes_box"
    )

    sign_in(user)
    get notes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(followup_path(followup, source_tag: "notes_box"))
  end
end
