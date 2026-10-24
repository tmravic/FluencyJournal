require "rails_helper"

RSpec.describe "Length limits", type: :request do
  let(:group) { Group.create!(name: "Limits #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "limits-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:journal) { Journal.create!(title: "Limits", user: user, group: group, last_interval: 1) }

  before { post session_path, params: { email_address: user.email_address, password: "password" } }

  it "shows a friendly message and saves nothing when an entry is too long" do
    expect {
      post journal_entries_path(journal), params: { entry: { content: "a" * 5_001 } }
    }.not_to change(Entry, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Content is too long (maximum is 5000 characters).")
  end

  it "shows the message in Japanese" do
    post journal_entries_path(journal, locale: "ja"), params: { entry: { content: "a" * 5_001 } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("5000文字以内で入力してください")
  end

  it "shows a friendly message when a note is too long" do
    expect {
      post notes_path, params: { note: { content: "a" * 5_001 } }
    }.not_to change(Note, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("too long (maximum is 5000 characters)")
  end

  it "shows a friendly message when a journal title is too long" do
    expect {
      post journals_path, params: { journal: { title: "a" * 256 } }
    }.not_to change(Journal, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Title is too long (maximum is 255 characters).")
  end

  it "still opens and edits an entry that is already over the limit" do
    entry = journal.entries.create!(content: "short")
    entry.update_columns(content: "a" * 6_000)

    get edit_journal_entry_path(journal, entry)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("a" * 6_000)

    get journal_path(journal)
    expect(response).to have_http_status(:ok)
  end

  describe "quiz answers" do
    let(:query) do
      prompt = PrepareQuizPrompt.create!(raw_prompt: "p", ai_model: Prompt::DEFAULT_MODEL,
                                         uuid: SecureRandom.uuid, sent_role_prompt: "r")
      AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}")
    end
    let(:question) { query.ai_outputs.create!(identifier: "1", role: :line, content: "Sentence", made_note: false) }
    let(:quiz) do
      journal.entries.create!(content: "文。")
      question
      Quiz.create!(journal: journal, ai_query: query)
    end

    it "refuses an over-long answer, keeps the earlier one, and caps the input in the form" do
      earlier = quiz.quiz_answers.create!(ai_output: question, user_response: "first try")
      path = journal_quiz_quiz_answers_path(journal, quiz)

      post path, params: { quiz_answer: { user_response: "a" * 5_001, ai_output_id: question.id } },
                 as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_entity)
      expect(quiz.quiz_answers.reload.pluck(:user_response)).to eq([ "first try" ])

      get retry_journal_quiz_quiz_answer_path(journal, quiz, earlier)
      expect(response.body).to include('maxlength="5000"')
    end
  end
end
