require "rails_helper"

# Scaffold leftovers that the app never linked to: entry index/show pages,
# the quiz answer "new" page and the JSON variants. They answer 404 (or 406
# for JSON on a route that remains) instead of rendering unused templates.
RSpec.describe "removed scaffold leftovers", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  let(:user) do
    group = Group.create!(name: "Scaffold #{SecureRandom.hex(4)}")
    User.create!(email_address: "scaffold-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:journal) { Journal.create!(title: "Scaffold", user: user, group: user.group, last_interval: 1) }
  let!(:entry) { journal.entries.create!(content: "一行") }

  before { sign_in(user) }

  it "has no entry index or show page" do
    get "/journals/#{journal.id}/entries"
    expect(response).to have_http_status(:not_found)

    get "/journals/#{journal.id}/entries/#{entry.id}"
    expect(response).to have_http_status(:not_found)
  end

  it "has no quiz answer new page" do
    prompt = PrepareQuizPrompt.create!(raw_prompt: "p", ai_model: Prompt::DEFAULT_MODEL, uuid: SecureRandom.uuid, sent_role_prompt: "r")
    query = AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}")
    quiz = Quiz.create!(journal: journal, ai_query: query)

    get "/journals/#{journal.id}/quizzes/#{quiz.id}/quiz_answers/new"

    expect(response).to have_http_status(:not_found)
  end

  it "does not serve JSON for journals" do
    get journals_path(format: :json)
    expect(response).to have_http_status(:not_acceptable)

    get journal_path(journal, format: :json)
    expect(response).to have_http_status(:not_acceptable)
  end

  it "does not accept JSON writes for journals and entries" do
    post journals_path(format: :json), params: { journal: { title: "x" } }
    expect(response).to have_http_status(:not_acceptable)
    expect(Journal.where(title: "x")).to be_empty

    patch journal_entry_path(journal, entry, format: :json), params: { entry: { content: "changed" } }
    expect(response).to have_http_status(:not_acceptable)
    expect(entry.reload.content).to eq("一行")

    delete journal_entry_path(journal, entry, format: :json)
    expect(response).to have_http_status(:not_acceptable)
    expect(Entry.exists?(entry.id)).to be(true)
  end

  it "still serves the pages the app uses" do
    get journal_path(journal)
    expect(response).to have_http_status(:ok)

    get edit_journal_entry_path(journal, entry)
    expect(response).to have_http_status(:ok)

    get new_journal_entry_path(journal)
    expect(response).to have_http_status(:ok)
  end
end
