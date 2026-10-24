require "rails_helper"

# BUG FIX: GET /followups/new with a Followup as the origin used to raise
# NoMethodError (a Followup had no #content), a 500.
RSpec.describe "GET /followups/new for a followup origin", type: :request do
  let(:group) { Group.create!(name: "New from followup #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(
      email_address: "new-from-followup-#{SecureRandom.hex(4)}@example.com", password: "password",
      original_language: "English", learning_language: "Japanese", group: group
    )
  end
  let(:journal) { Journal.create!(title: "Journal", user: user, group: group, last_interval: 1) }
  let(:entry) { journal.entries.create!(content: "今日は雨だった。") }
  let(:parent) do
    prompt = FreeQuestionPrompt.create!(
      raw_prompt: "Followup Question: why?\nReference text: 雨", user_generated_content: "雨",
      ai_model: Prompt::DEFAULT_MODEL, uuid: SecureRandom.uuid, sent_role_prompt: "r"
    )
    Followup.create!(prompt: prompt, origin: entry, source_tag: "ai_assistant")
  end

  before { post session_path, params: { email_address: user.email_address, password: "password" } }

  it "renders the form with the parent followup's reference text" do
    get new_followup_path(class_name: "Followup", id: parent.id, source_tag: "ai_assistant")

    expect(response).to have_http_status(:ok)
    expect(response.body).to match(%r{<textarea[^>]*>\s*雨</textarea>})
  end

  it "renders the form with an empty reference text when the parent had none" do
    parent.prompt.update!(user_generated_content: nil)

    get new_followup_path(class_name: "Followup", id: parent.id, source_tag: "ai_assistant")

    expect(response).to have_http_status(:ok)
  end
end
