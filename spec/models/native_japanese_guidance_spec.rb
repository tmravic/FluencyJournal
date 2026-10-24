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

  it "adds native phrasing to Japanese quiz preparation prompts" do
    user = japanese_user
    text = PrepareQuizPrompt.new.role_prompt(user, nil)

    expect(text).to include("not textbook Japanese")
    expect(text).to include("short question in Japanese")

    journal = instance_double(Journal, entry_texts: [ "今日は雨だった。" ], user: user)
    format = PrepareQuizPrompt.new.response_format(user, journal, nil)

    expect(format).to include("exactly 1")
    expect(format).to include('"hint"')
  end

  it "adds diary guidance to Japanese quiz-result prompts" do
    text = QuizResultPrompt.new.role_prompt(japanese_user, nil)

    expect(text).to include("personal journal")
    expect(text).to include("飲みすぎちゃった")
  end

  it "omits Japanese-only guidance for English learners" do
    expect(ExampleSentencePrompt.new.role_prompt(english_user, journal_double)).not_to include("not textbook Japanese")
    expect(FreeQuestionPrompt.new.role_prompt(english_user, nil)).not_to include("not textbook Japanese")
    expect(PrepareQuizPrompt.new.role_prompt(english_user, nil)).not_to include("not textbook Japanese")
    expect(QuizResultPrompt.new.role_prompt(english_user, nil)).not_to include("personal journal")
  end
end
