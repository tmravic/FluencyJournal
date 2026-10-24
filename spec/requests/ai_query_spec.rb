require "rails_helper"

RSpec.describe "AiQueries", type: :request do
  let(:group) { Group.create!(name: "AiQueries #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "ai-queries-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:journal) { Journal.create!(title: "Ai query journal", user: user, group: group, last_interval: 1) }
  let(:prompt) do
    EntryPrompt.create!(raw_prompt: "entry", ai_model: Prompt::DEFAULT_MODEL, uuid: SecureRandom.uuid,
                        sent_role_prompt: "role")
  end
  let(:ai_query) { AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}") }

  before { post session_path, params: { email_address: user.email_address, password: "password" } }

  describe "GET /journals/:journal_id/ai_queries/:id" do
    it "renders the corrected text card with its actions" do
      output = ai_query.ai_outputs.create!(identifier: "corrected_text", content: "訂正された文です。",
                                           made_note: false, role: :line)

      get journal_ai_query_path(journal, ai_query)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="ai_assistant"')
      expect(response.body).to include(I18n.t("ai_query.corrected_text"))
      expect(response.body).to include(ai_output_path(output))
      expect(response.body).to include(journal_ai_query_path(journal, ai_query))
    end

    it "renders a query that has no corrected text" do
      get journal_ai_query_path(journal, ai_query)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="ai_assistant"')
    end
  end

  describe "the old scaffold path" do
    it "does not exist" do
      get "/ai_queries/show"

      expect(response).to have_http_status(:not_found)
    end
  end
end
