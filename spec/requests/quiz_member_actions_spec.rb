require "rails_helper"

RSpec.describe "Quiz member UI actions", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_quiz
    group = Group.create!(name: "Quiz member #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "quiz-member-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Quiz journal", user: user, group: group, last_interval: 1)
    entry = journal.entries.create!(content: "一行目")
    prompt = Prompt.create!(
      raw_prompt: "prepare",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    query = AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}")
    output = query.ai_outputs.create!(identifier: "1", content: "I met her mother.", made_note: false)
    quiz = Quiz.create!(journal: journal, ai_query: query)
    QuizHint.create!(quiz: quiz, entry: entry, ai_query: query, hint_content: "a small hint")

    other_prompt = Prompt.create!(
      raw_prompt: "other",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    other_query = AiQuery.create!(journal: journal, prompt: other_prompt, raw_response: "{}")
    other_output = other_query.ai_outputs.create!(identifier: "1", content: "someone else", made_note: false)

    [ user, journal, quiz, output, other_output ]
  end

  def turbo_get(path)
    get path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  it "loads peek, unpeek, hint, and original language for this quiz output" do
    user, journal, quiz, output, = create_quiz
    sign_in(user)

    turbo_get peek_journal_quiz_path(journal, quiz, ai_output_id: output.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("一行目")
    expect(response.body).to include(%(target="ai_output_#{output.id}"))
    expect(response.body).to include("/journals/#{journal.id}/quizzes/#{quiz.id}/unpeek?ai_output_id=#{output.id}")
    expect(response.body).not_to match(/[?&]frame=/)

    turbo_get unpeek_journal_quiz_path(journal, quiz, ai_output_id: output.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(target="ai_output_#{output.id}"))
    expect(response.body).to include("I met her mother.")
    expect(response.body).to include("/journals/#{journal.id}/quizzes/#{quiz.id}/peek?ai_output_id=#{output.id}")
    expect(response.body).not_to match(/[?&]frame=/)

    turbo_get show_hint_journal_quiz_path(journal, quiz, ai_output_id: output.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("a small hint")
    expect(response.body).to include("/journals/#{journal.id}/quizzes/#{quiz.id}/hide_hint?ai_output_id=#{output.id}")

    turbo_get hide_hint_journal_quiz_path(journal, quiz, ai_output_id: output.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/journals/#{journal.id}/quizzes/#{quiz.id}/show_hint?ai_output_id=#{output.id}")

    turbo_get show_original_language_journal_quiz_path(journal, quiz, ai_output_id: output.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("I met her mother.")
    expect(response.body).to include("/journals/#{journal.id}/quizzes/#{quiz.id}/hide_original_language?ai_output_id=#{output.id}")

    turbo_get hide_original_language_journal_quiz_path(journal, quiz, ai_output_id: output.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/journals/#{journal.id}/quizzes/#{quiz.id}/show_original_language?ai_output_id=#{output.id}")
  end

  it "refuses an output that does not belong to this quiz" do
    user, journal, quiz, _output, other_output = create_quiz
    sign_in(user)

    turbo_get peek_journal_quiz_path(journal, quiz, ai_output_id: other_output.id)

    expect(response).to have_http_status(:not_found)
  end

  it "returns 422 when this quiz has no hint for the entry" do
    user, journal, quiz, output, = create_quiz
    quiz.quiz_hints.destroy_all
    sign_in(user)

    turbo_get show_hint_journal_quiz_path(journal, quiz, ai_output_id: output.id)

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
