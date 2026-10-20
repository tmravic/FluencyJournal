require "rails_helper"

RSpec.describe "Quiz prompt text", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  it "stores the prepare-quiz raw prompt as a JSON array of entries" do
    group = Group.create!(name: "Quiz prompt #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "quiz-prompt-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Quiz prompt", user: user, group: group, last_interval: 1)
    journal.entries.create!(content: "一行目")
    journal.entries.create!(content: "二行目")
    sign_in(user)
    allow(PrepareQuizJob).to receive(:perform_later)

    post prepare_quiz_journal_quizzes_path(journal)

    expect(JSON.parse(PrepareQuizPrompt.last.raw_prompt)).to eq([ "一行目", "二行目" ])
  end
end
