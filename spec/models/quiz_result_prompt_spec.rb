require "rails_helper"

RSpec.describe QuizResultPrompt, type: :model do
  it "builds a role prompt without run-together sentences or doubled words" do
    user = User.new(original_language: "English", learning_language: "Japanese")
    text = described_class.new.role_prompt(user, nil)

    expect(text).to include("based roughly on the original. Compare my Japanese Quiz Answers")
    expect(text).not_to match(/\b(\w+) \1\b/)
  end
end
