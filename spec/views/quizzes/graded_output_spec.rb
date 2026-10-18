require "rails_helper"

RSpec.describe "quizzes/graded_output", type: :view do
  it "renders the retry link as a GET visit without a UJS method" do
    group = Group.create!(name: "Retry group #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "retry-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Retry", user: user, group: group, last_interval: 1)
    prompt = QuizResultPrompt.create!(
      raw_prompt: "grade",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    grading_query = AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}")
    output = grading_query.ai_outputs.create!(identifier: "1", content: "entry card", made_note: false)
    quiz = Quiz.create!(journal: journal, ai_query: grading_query)
    quiz_answer = quiz.quiz_answers.create!(ai_output: output, user_response: "会いました")

    expect(quiz.quiz_answers.slice(0)).to eq(quiz_answer)

    render partial: "quizzes/graded_output", locals: {
      assessment: "",
      ai_query_id: grading_query.id,
      source_tag: "ai_assistant",
      user: user,
      quiz: quiz
    }

    retry_path = retry_journal_quiz_quiz_answer_path(journal, quiz, quiz_answer)
    expect(rendered).to include(retry_path)

    link = rendered[/<a\b[^<]*href="#{Regexp.escape(retry_path)}"[^<]*<\/a>/m]
    expect(link).to be_present
    expect(link).to include(%(data-turbo-frame="quiz_answer_1"))
    expect(link).to include(%(data-controller="scroll"))
    expect(link).to include("scroll#scrollToTarget")
    expect(link).to include(%(data-scroll-target-value="quiz_answer_1"))
    expect(link).to include("data-turbo-confirm=")
    expect(link).to include(%(class="btn btn--dark"))
    expect(link).not_to include("data-method")
    expect(link).not_to include("turbo-method")
  end
end
