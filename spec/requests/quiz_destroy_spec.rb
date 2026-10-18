require "rails_helper"

RSpec.describe "DELETE /journals/:journal_id/quizzes/:id", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_quiz
    group = Group.create!(name: "Quiz delete #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "quiz-delete-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Quiz journal", user: user, group: group, last_interval: 1)
    entry = journal.entries.create!(content: "一行目")
    prepare_prompt = Prompt.create!(
      raw_prompt: "prepare",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    prepare_query = AiQuery.create!(journal: journal, prompt: prepare_prompt, raw_response: "{}")
    grading_prompt = QuizResultPrompt.create!(
      raw_prompt: "grade",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    grading_query = AiQuery.create!(journal: journal, prompt: grading_prompt, raw_response: "{}")
    grading_query.ai_outputs.create!(identifier: "assessment", content: "ok", made_note: false)
    quiz = Quiz.create!(journal: journal, ai_query: prepare_query, grading_ai_query: grading_query)
    QuizHint.create!(quiz: quiz, entry: entry, ai_query: prepare_query, hint_content: "hint")

    [ user, journal, quiz, prepare_query, grading_query ]
  end

  it "deletes the quiz and restores the journal over Turbo" do
    user, journal, quiz, prepare_query, grading_query = create_quiz
    sign_in(user)

    delete journal_quiz_path(journal, quiz),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include(%(target="compare_button"))
    expect(response.body).to include(I18n.t("journal.actions.compare"))
    expect(response.body).to include('id="entries"')
    expect(response.body).to include("一行目")
    expect(response.body).to include(%(target="quiz_buttons"))
    expect(Quiz.exists?(quiz.id)).to be(false)
    expect(AiQuery.exists?(prepare_query.id)).to be(false)
    expect(AiQuery.exists?(grading_query.id)).to be(false)
    expect(QuizHint.where(quiz_id: quiz.id)).to be_empty
  end

  it "redirects a non-Turbo delete back to the journal" do
    user, journal, quiz, = create_quiz
    sign_in(user)

    delete journal_quiz_path(journal, quiz)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journal_path(journal))
    expect(Quiz.exists?(quiz.id)).to be(false)
  end
end
