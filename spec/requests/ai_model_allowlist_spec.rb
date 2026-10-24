require "rails_helper"

# The model select offers two models, but a crafted POST used to be able to
# save and enqueue any model id. Only Prompt::MODELS are accepted now.
RSpec.describe "AI model allowlist", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  let(:group) { Group.create!(name: "Model list #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(
      email_address: "model-list-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end
  let(:journal) { Journal.create!(title: "Model list", user: user, group: group, last_interval: 1) }
  let(:turbo_stream_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  def post_ai_request(model)
    post ai_request_journal_ai_queries_path(journal),
         params: { entry_prompt: { base_content: "Hello", user_generated_content: "こんにちは",
                                   ai_model: model, uuid: SecureRandom.uuid } },
         headers: turbo_stream_headers
  end

  def post_followup(model, entry)
    post followups_path,
         params: { followup: { source_tag: "ai_assistant", followup_origin_class: "Entry",
                               followup_origin_id: entry.id, journal_id: journal.id,
                               followup_prompt: { base_content: "What does this mean?",
                                                  user_generated_content: "一行",
                                                  ai_model: model, uuid: SecureRandom.uuid } } },
         headers: turbo_stream_headers
  end

  before { sign_in(user) }

  it "offers exactly the allowed models in the AI request form" do
    get journal_path(journal)
    get open_ai_assistant_journal_path(journal), headers: turbo_stream_headers

    values = Nokogiri::HTML(response.body).css("select#entry_prompt_ai_model option").map { |o| o["value"] }
    expect(values).to eq(Prompt::MODELS)
  end

  it "answers 422 and enqueues nothing for an unknown model on an AI request" do
    expect(AiRequestJob).not_to receive(:perform_later)

    expect { post_ai_request("some-expensive-model-x") }.not_to change(Prompt, :count)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "accepts every allowed model on an AI request" do
    Prompt::MODELS.each do |model|
      expect { post_ai_request(model) }.to change(Prompt, :count).by(1)
      expect(response).to have_http_status(:ok)
    end
  end

  it "answers 422 and enqueues nothing for an unknown model on a followup" do
    entry = journal.entries.create!(content: "一行")
    expect(FollowupRequestJob).not_to receive(:perform_later)

    expect { post_followup("grok-3", entry) }.not_to change { [ Prompt.count, Followup.count ] }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "accepts an allowed model on a followup" do
    entry = journal.entries.create!(content: "一行")

    expect { post_followup(Prompt::DEFAULT_MODEL, entry) }.to change(Followup, :count).by(1)
  end
end
