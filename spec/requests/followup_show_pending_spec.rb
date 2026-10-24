require "rails_helper"

RSpec.describe "followup show before its AI query exists", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user
    group = Group.create!(name: "Pending followup #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "pending-followup-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def create_followup(user, with_ai_query:)
    journal = Journal.create!(title: "Pending", user: user, group: user.group, last_interval: 1)
    entry = journal.entries.create!(content: "一行")
    prompt = Prompt.create!(
      type: "FreeQuestionPrompt",
      raw_prompt: "prompt",
      sent_role_prompt: "role",
      ai_model: Prompt::DEFAULT_MODEL,
      uuid: SecureRandom.uuid,
      base_content: "question",
      user_generated_content: "reference"
    )
    followup = Followup.create!(origin: entry, prompt: prompt, source_tag: "ai_assistant")
    AiQuery.create!(raw_response: "{}", prompt: prompt, journal: journal) if with_ai_query
    followup
  end

  it "shows the processing text instead of raising while the job has not produced a query" do
    user = create_user
    followup = create_followup(user, with_ai_query: false)
    sign_in(user)

    get followup_path(followup, source_tag: "ai_assistant")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("ai_query.processing"))
    expect(response.body).to include(I18n.t("followup.not_ready"))
    expect(response.body).to include('<turbo-frame id="followup_output_ai_assistant"')
  end

  it "shows the processing state inside the notes box wrapper for the notes box source" do
    user = create_user
    followup = create_followup(user, with_ai_query: false)
    sign_in(user)

    get followup_path(followup, source_tag: "notes_box")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('class="notes-box"')
    expect(response.body).to include('<turbo-frame id="notes_box"')
  end

  it "does not show the processing state once the query exists" do
    user = create_user
    followup = create_followup(user, with_ai_query: true)
    sign_in(user)

    get followup_path(followup, source_tag: "ai_assistant")

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(I18n.t("followup.not_ready"))
  end
end
