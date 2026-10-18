require "rails_helper"

RSpec.describe "graded quiz ownership", type: :model do
  def create_graded_quiz
    group = Group.create!(name: "Graded quiz #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "graded-quiz-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Graded journal", user: user, group: group, last_interval: 1)
    prepare_prompt = PrepareQuizPrompt.create!(
      raw_prompt: "prepare",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    prepare_query = AiQuery.create!(journal: journal, prompt: prepare_prompt, raw_response: "{}")
    grade_prompt = QuizResultPrompt.create!(
      raw_prompt: "grade",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    grade_query = AiQuery.create!(
      journal: journal,
      prompt: grade_prompt,
      raw_response: { "assessment" => "Fine." }.to_json
    )
    quiz = Quiz.create!(journal: journal, ai_query: prepare_query, grading_ai_query: grade_query)

    [ journal, quiz, prepare_query, grade_query ]
  end

  it "keeps the quiz when the grading query is deleted" do
    _journal, quiz, prepare_query, grade_query = create_graded_quiz

    grade_query.destroy!

    quiz.reload
    expect(Quiz.exists?(quiz.id)).to be(true)
    expect(quiz.ai_query_id).to eq(prepare_query.id)
    expect(quiz.grading_ai_query_id).to be_nil
    expect(prepare_query.quizzes).to contain_exactly(quiz)
    expect(AiQuery.exists?(grade_query.id)).to be(false)
  end

  it "removes the quiz with the journal" do
    journal, quiz, prepare_query, grade_query = create_graded_quiz

    journal.destroy!

    expect(Quiz.exists?(quiz.id)).to be(false)
    expect(AiQuery.exists?(prepare_query.id)).to be(false)
    expect(AiQuery.exists?(grade_query.id)).to be(false)
  end
end
