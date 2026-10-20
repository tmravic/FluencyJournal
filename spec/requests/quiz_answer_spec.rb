require 'rails_helper'

RSpec.describe "QuizAnswers", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_quiz_with_questions(count: 2)
    group = Group.create!(name: "Quiz answers #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "quiz-answers-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Quiz answers journal", user: user, group: group, last_interval: 1)
    count.times { |i| journal.entries.create!(content: "文#{i + 1}。") }
    prompt = PrepareQuizPrompt.create!(
      raw_prompt: "prepare",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    query = AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}")
    questions = (1..count).map do |n|
      query.ai_outputs.create!(identifier: n.to_s, role: :line, content: "Sentence #{n}", made_note: false)
    end
    quiz = Quiz.create!(journal: journal, ai_query: query)

    [ user, journal, quiz, questions ]
  end

  def answer(journal, quiz, question)
    post journal_quiz_quiz_answers_path(journal, quiz),
         params: { quiz_answer: { user_response: "答え", ai_output_id: question.id, identifier: question.identifier } },
         as: :turbo_stream
  end

  describe "POST create" do
    it "derives the grade button from saved answers, without needing quiz state in the session" do
      user, journal, quiz, (first, second) = create_quiz_with_questions
      sign_in(user) # no prepare_quiz request in this session

      answer(journal, quiz, first)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('target="grade_quiz_button"')

      answer(journal, quiz, second)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('target="grade_quiz_button"')
    end
  end

  describe "POST create original text" do
    it "shows the entry for the answered question, ignoring any identifier param" do
      user, journal, quiz, (_first, second) = create_quiz_with_questions
      sign_in(user)

      post journal_quiz_quiz_answers_path(journal, quiz),
           params: { quiz_answer: { user_response: "答え", ai_output_id: second.id, identifier: "1" } },
           as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("文2。")
      expect(response.body).not_to include("文1。")
    end
  end

  describe "Quiz#fully_answered?" do
    it "counts each question once, even when answered twice" do
      _user, _journal, quiz, (first, second) = create_quiz_with_questions

      2.times { quiz.quiz_answers.create!(ai_output: first, user_response: "a") }
      expect(quiz.fully_answered?).to be(false)

      quiz.quiz_answers.create!(ai_output: second, user_response: "b")
      expect(quiz.fully_answered?).to be(true)
    end
  end
end
