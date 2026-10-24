require "rails_helper"

RSpec.describe "grade_quiz guards", type: :request do
  include ActiveJob::TestHelper

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def prompt!(klass)
    klass.create!(raw_prompt: "p", ai_model: Prompt::DEFAULT_MODEL, uuid: SecureRandom.uuid, sent_role_prompt: "role")
  end

  let(:user) do
    group = Group.create!(name: "Grade guards #{SecureRandom.hex(4)}")
    User.create!(email_address: "grade-guards-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:journal) do
    Journal.create!(title: "Guards", user: user, group: user.group, last_interval: 1).tap do |j|
      j.entries.create!(content: "一行目")
      j.entries.create!(content: "二行目")
    end
  end
  let(:prepare) { AiQuery.create!(journal: journal, prompt: prompt!(PrepareQuizPrompt), raw_response: "{}") }
  let!(:q1) { prepare.ai_outputs.create!(identifier: "1", content: "One", made_note: false) }
  let!(:q2) { prepare.ai_outputs.create!(identifier: "2", content: "Two", made_note: false) }
  let(:quiz) { Quiz.create!(journal: journal, ai_query: prepare) }
  let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html" } }

  around do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = original
  end

  before { sign_in(user) }

  def answer_all
    quiz.quiz_answers.create!(ai_output: q1, user_response: "a")
    quiz.quiz_answers.create!(ai_output: q2, user_response: "b")
  end

  it "grades a fully answered quiz once and enqueues one job" do
    answer_all

    expect do
      post grade_quiz_journal_quiz_path(journal, quiz), headers: turbo
    end.to have_enqueued_job(GradeQuizJob).once

    expect(response).to have_http_status(:ok)
    expect(quiz.reload.grading_requested_at).to be_present
  end

  it "enqueues only one job when the button is submitted twice" do
    answer_all

    expect do
      2.times { post grade_quiz_journal_quiz_path(journal, quiz), headers: turbo }
    end.to have_enqueued_job(GradeQuizJob).once

    expect(response).to have_http_status(:unprocessable_entity)
    expect(QuizResultPrompt.count).to eq(1)
  end

  it "rejects a quiz that is not fully answered" do
    quiz.quiz_answers.create!(ai_output: q1, user_response: "a")

    expect do
      post grade_quiz_journal_quiz_path(journal, quiz), headers: turbo
    end.not_to have_enqueued_job(GradeQuizJob)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(QuizResultPrompt.count).to eq(0)
    expect(quiz.reload.grading_requested_at).to be_nil
  end

  it "rejects a quiz that is already graded" do
    answer_all
    grading = AiQuery.create!(journal: journal, prompt: prompt!(QuizResultPrompt), raw_response: "{}")
    quiz.update!(grading_ai_query: grading)

    expect do
      post grade_quiz_journal_quiz_path(journal, quiz), headers: turbo
    end.not_to have_enqueued_job(GradeQuizJob)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "allows grading again once a pending request is old enough to be treated as lost" do
    answer_all
    quiz.update!(grading_requested_at: (Quiz::GRADING_PENDING_FOR + 1.minute).ago)

    expect do
      post grade_quiz_journal_quiz_path(journal, quiz), headers: turbo
    end.to have_enqueued_job(GradeQuizJob).once
  end

  it "releases the claim when the prompt cannot be saved" do
    answer_all
    allow_any_instance_of(QuizResultPrompt).to receive(:save).and_return(false)

    post grade_quiz_journal_quiz_path(journal, quiz), headers: turbo

    expect(response).to have_http_status(:unprocessable_entity)
    expect(quiz.reload.grading_requested_at).to be_nil
  end

  it "renders the grade button so that it disables itself while submitting" do
    answer_all
    html = ApplicationController.render(GradeQuizButtonComponent.new(journal: journal, quiz: quiz), layout: false)

    expect(html).to include("data-turbo-submits-with=")
  end

  it "makes the quiz gradable again when the grading job is discarded" do
    answer_all
    quiz.update!(grading_requested_at: Time.current)
    allow(XAiChat).to receive(:complete).and_raise(JSON::ParserError, "not json")

    GradeQuizJob.perform_now(journal, prompt!(QuizResultPrompt), quiz)

    expect(quiz.reload.grading_requested_at).to be_nil
    expect(quiz.grading_pending?).to be(false)
  end
end
