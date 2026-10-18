require "rails_helper"

RSpec.describe "graded quiz show", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_graded_quiz
    group = Group.create!(name: "Quiz show #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "quiz-show-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Quiz show journal", user: user, group: group, last_interval: 1)
    journal.entries.create!(content: "一行目")
    prepare_prompt = PrepareQuizPrompt.create!(
      raw_prompt: "prepare",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    prepare_query = AiQuery.create!(
      journal: journal,
      prompt: prepare_prompt,
      raw_response: { "line_1" => { "translation" => "PREPARE_QUESTION_ONLY" } }.to_json
    )
    prepare_query.ai_outputs.create!(identifier: "1", content: "PREPARE_QUESTION_ONLY", made_note: false)
    grade_prompt = QuizResultPrompt.create!(
      raw_prompt: "grade",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    grade_query = AiQuery.create!(
      journal: journal,
      prompt: grade_prompt,
      raw_response: {
        "entry_1" => {
          "content" => "会いました → 会いました",
          "explanation_en" => "GRADE_EXPLANATION_UNIQUE"
        },
        "assessment" => "GRADE_ASSESSMENT_UNIQUE"
      }.to_json
    )
    grade_query.ai_outputs.create!(identifier: "1", content: "entry card", made_note: false, role: :line)
    grade_query.ai_outputs.create!(identifier: "assessment", content: "GRADE_ASSESSMENT_UNIQUE", made_note: false, role: :assessment)
    quiz = Quiz.create!(journal: journal, ai_query: prepare_query, grading_ai_query: grade_query)

    [ user, journal, quiz, prepare_query, grade_query ]
  end

  it "renders the grading query on the quiz page and links the history chip to that quiz" do
    user, journal, quiz, prepare_query, grade_query = create_graded_quiz
    sign_in(user)

    get journal_quiz_path(journal, quiz)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("GRADE_ASSESSMENT_UNIQUE")
    expect(response.body).to include("GRADE_EXPLANATION_UNIQUE")
    expect(response.body).to include("ai_query_id=#{grade_query.id}")
    expect(response.body).not_to include("PREPARE_QUESTION_ONLY")
    expect(response.body).not_to include("ai_query_id=#{prepare_query.id}")

    get journal_path(journal)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(journal_quiz_path(journal, quiz))
    expect(response.body).not_to include(journal_ai_query_path(journal, prepare_query))
    expect(response.body).not_to include(journal_ai_query_path(journal, grade_query))
  end

  it "leaves the quiz in place when the grading query is deleted" do
    user, journal, quiz, prepare_query, grade_query = create_graded_quiz
    sign_in(user)

    delete journal_ai_query_path(journal, grade_query),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(I18n.t("journal.open_ai_assistant"))
    quiz.reload
    expect(quiz.ai_query_id).to eq(prepare_query.id)
    expect(quiz.grading_ai_query_id).to be_nil
    expect(AiQuery.exists?(grade_query.id)).to be(false)
    expect(AiQuery.exists?(prepare_query.id)).to be(true)
  end
end
