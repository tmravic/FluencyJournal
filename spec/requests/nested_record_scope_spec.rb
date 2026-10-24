require "rails_helper"

RSpec.describe "Nested record scope", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user(label)
    group = Group.create!(name: "Nested scope #{label} #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "nested-#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def create_journal(user, title)
    Journal.create!(title: title, user: user, group: user.group, last_interval: 1)
  end

  def create_prompt
    Prompt.create!(
      raw_prompt: "nested scope",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
  end

  def create_query(journal)
    AiQuery.create!(journal: journal, prompt: create_prompt, raw_response: "{}")
  end

  def two_groups
    user_a = create_user("a")
    user_b = create_user("b")
    journal_a = create_journal(user_a, "Journal A")
    journal_b = create_journal(user_b, "Journal B")
    entry_a = journal_a.entries.create!(content: "line a")
    entry_b = journal_b.entries.create!(content: "line b")
    query_a = create_query(journal_a)
    query_b = create_query(journal_b)
    output_a = query_a.ai_outputs.create!(identifier: "1", content: "output a", made_note: false)
    output_b = query_b.ai_outputs.create!(identifier: "1", content: "output b", made_note: false)
    quiz_a = Quiz.create!(journal: journal_a, ai_query: query_a)
    quiz_b = Quiz.create!(journal: journal_b, ai_query: query_b)
    answer_b = quiz_b.quiz_answers.create!(ai_output: output_b, user_response: "answer b")

    {
      user_a: user_a,
      journal_a: journal_a,
      entry_a: entry_a,
      query_a: query_a,
      output_a: output_a,
      quiz_a: quiz_a,
      journal_b: journal_b,
      entry_b: entry_b,
      query_b: query_b,
      output_b: output_b,
      answer_b: answer_b
    }
  end

  it "returns 404 for another group's entry and 200 for this journal's entry" do
    records = two_groups
    sign_in(records[:user_a])

    get edit_journal_entry_path(records[:journal_a], records[:entry_b])

    expect(response).to have_http_status(:not_found)

    get edit_journal_entry_path(records[:journal_a], records[:entry_a])

    expect(response).to have_http_status(:ok)
  end

  it "keeps the entry on the journal in the URL when journal_id is posted" do
    records = two_groups
    sign_in(records[:user_a])

    patch journal_entry_path(records[:journal_a], records[:entry_a]),
          params: { entry: { content: "kept", journal_id: records[:journal_b].id } }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journal_path(records[:journal_a]))
    records[:entry_a].reload
    expect(records[:entry_a].content).to eq("kept")
    expect(records[:entry_a].journal_id).to eq(records[:journal_a].id)
  end

  it "returns 404 for another group's ai query" do
    records = two_groups
    sign_in(records[:user_a])

    get journal_ai_query_path(records[:journal_a], records[:query_b])

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for a quiz answer that belongs to another quiz" do
    records = two_groups
    sign_in(records[:user_a])

    get journal_quiz_quiz_answer_path(records[:journal_a], records[:quiz_a], records[:answer_b])

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 and does not save when the posted output belongs to another quiz" do
    records = two_groups
    sign_in(records[:user_a])

    expect {
      post journal_quiz_quiz_answers_path(records[:journal_a], records[:quiz_a]),
           params: {
             quiz_answer: {
               user_response: "x",
               ai_output_id: records[:output_b].id,
               identifier: "1"
             }
           },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    }.not_to change(QuizAnswer, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "returns a turbo stream for an output on this quiz" do
    records = two_groups
    sign_in(records[:user_a])

    post journal_quiz_quiz_answers_path(records[:journal_a], records[:quiz_a]),
         params: {
           quiz_answer: {
             user_response: "x",
             ai_output_id: records[:output_a].id,
             identifier: "1"
           }
         },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).not_to have_http_status(:not_found)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
  end
end
