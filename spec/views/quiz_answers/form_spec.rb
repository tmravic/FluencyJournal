require "rails_helper"

# BUG FIX: the form's data-turbo-frame used to be the AiOutput serialized as
# JSON instead of a frame id.
RSpec.describe "quiz_answers/form", type: :view do
  it "targets the question's turbo frame by id" do
    group = Group.create!(name: "Quiz form #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "quiz-form-#{SecureRandom.hex(4)}@example.com", password: "password",
      original_language: "English", learning_language: "Japanese", group: group
    )
    journal = Journal.create!(title: "Quiz form", user: user, group: group, last_interval: 1)
    prompt = PrepareQuizPrompt.create!(
      raw_prompt: "prepare", ai_model: "grok-4-fast-non-reasoning", uuid: SecureRandom.uuid, sent_role_prompt: "role"
    )
    query = AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}")
    output = query.ai_outputs.create!(identifier: "1", content: "I met her mother.", made_note: false)
    quiz = Quiz.create!(journal: journal, ai_query: query)

    render partial: "quiz_answers/form", locals: {
      journal: journal, quiz: quiz, quiz_answer: quiz.quiz_answers.build(ai_output: output), quiz_entry: output
    }

    form = rendered[/<form\b[^>]*>/m]
    expect(form).to include(%(data-turbo-frame="ai_output_#{output.id}"))
    expect(form).not_to include("&quot;")
  end
end
