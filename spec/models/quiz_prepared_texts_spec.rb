require "rails_helper"

RSpec.describe Quiz, "#prepared_texts" do
  def build_quiz
    group = Group.create!(name: "Prepared texts #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "prepared-texts-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Prepared journal", user: user, group: group, last_interval: 1)
    prompt = PrepareQuizPrompt.create!(
      raw_prompt: "prepare",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    query = AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}")
    Quiz.create!(journal: journal, ai_query: query)
  end

  it "returns the question texts in the order they were saved, even after a row is updated" do
    quiz = build_quiz
    first = quiz.ai_query.ai_outputs.create!(identifier: "1", content: "first", made_note: false)
    quiz.ai_query.ai_outputs.create!(identifier: "2", content: "second", made_note: false)
    quiz.ai_query.ai_outputs.create!(identifier: "3", content: "third", made_note: false)

    # An UPDATE moves the row in the table heap, so an unordered SELECT
    # would return it last.
    first.update!(content: "first, edited")

    expect(quiz.prepared_texts).to eq([ "first, edited", "second", "third" ])
  end
end
