require "rails_helper"

RSpec.describe NativeJapaneseGuidance do
  def japanese_user
    instance_double(User, learning_language: "Japanese", original_language: "English")
  end

  def english_user
    instance_double(User, learning_language: "English", original_language: "Japanese")
  end

  def journal_double
    instance_double(Journal, entry_texts: [ "今日は雨だった。" ])
  end

  it "adds native phrasing to Japanese example-sentence prompts" do
    text = ExampleSentencePrompt.new.role_prompt(japanese_user, journal_double)

    expect(text).to include("not textbook Japanese")
  end

  it "adds native phrasing to Japanese followup prompts" do
    text = FreeQuestionPrompt.new.role_prompt(japanese_user, nil)

    expect(text).to include("not textbook Japanese")
  end

  it "omits Japanese-only guidance for English learners" do
    expect(ExampleSentencePrompt.new.role_prompt(english_user, journal_double)).not_to include("not textbook Japanese")
    expect(FreeQuestionPrompt.new.role_prompt(english_user, nil)).not_to include("not textbook Japanese")
  end
end
