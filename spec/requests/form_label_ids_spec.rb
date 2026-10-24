require "rails_helper"

# Labels must point at a real control, and element ids must be unique on a
# page. The followup form passed the translated text as the field name, and
# two request-form partials hard-coded the same textarea ids.
RSpec.describe "Form labels and ids", type: :request do
  let(:group) { Group.create!(name: "Labels #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(
      email_address: "labels-#{SecureRandom.hex(4)}@example.com", password: "password",
      original_language: "English", learning_language: "Japanese", group: group
    )
  end
  let(:journal) { Journal.create!(title: "Journal", user: user, group: group, last_interval: 1) }
  let(:entry) { journal.entries.create!(content: "今日は雨だった。") }

  before { post session_path, params: { email_address: user.email_address, password: "password" } }

  def label_targets(body)
    body.scan(/<label[^>]*\sfor="([^"]+)"/).flatten
  end

  def ids(body)
    body.scan(/\sid="([^"]+)"/).flatten
  end

  def expect_labels_to_have_controls(body)
    missing = label_targets(body) - ids(body)
    expect(missing).to be_empty
  end

  def expect_unique_ids(body)
    expect(ids(body).tally.select { |_, count| count > 1 }.keys).to be_empty
  end

  it "ties the followup form labels to their textareas" do
    get new_followup_path(class_name: "Entry", id: entry.id, source_tag: "ai_assistant")

    expect(label_targets(response.body).size).to be >= 2
    expect_labels_to_have_controls(response.body)
  end

  it "gives the read-only request form on followups#show labelled, unique textareas" do
    prompt = FreeQuestionPrompt.create!(
      raw_prompt: "Followup Question: why?", base_content: "why?", user_generated_content: "雨",
      ai_model: "m", uuid: SecureRandom.uuid, sent_role_prompt: "r"
    )
    followup = Followup.create!(prompt: prompt, origin: entry, source_tag: "ai_assistant")
    AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}")

    get followup_path(followup)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(id="base_content_followup_#{followup.id}"))
    expect_labels_to_have_controls(response.body)
    expect_unique_ids(response.body)
  end

  it "gives the read-only request form on ai_queries#show labelled textareas named after the query" do
    prompt = EntryPrompt.create!(
      raw_prompt: "x", base_content: "I rain", user_generated_content: "雨", ai_model: "m",
      uuid: SecureRandom.uuid, sent_role_prompt: "r"
    )
    query = AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}")

    get journal_ai_query_path(journal, query)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(id="base_content_ai_query_#{query.id}"))
    expect_labels_to_have_controls(response.body)
    expect_unique_ids(response.body)
  end
end
