require "rails_helper"

RSpec.describe EntryPrompt, type: :model do
  def user_double(learning_language:, original_language:)
    instance_double(User, learning_language: learning_language, original_language: original_language)
  end

  def journal_double
    instance_double(Journal, full_journal: [ "今日は雨だった。" ])
  end

  describe "#role_prompt" do
    it "adds native diary guidance for Japanese learners" do
      text = described_class.new.role_prompt(
        user_double(learning_language: "Japanese", original_language: "English"),
        journal_double
      )

      expect(text).to include("personal journal")
      expect(text).to include("です/ます")
      expect(text).to include("飲みすぎちゃった")
      expect(text).to include("'Learning Language' is already grammatical and natural")
    end

    it "does not add Japanese diary guidance for other learning languages" do
      text = described_class.new.role_prompt(
        user_double(learning_language: "English", original_language: "Japanese"),
        journal_double
      )

      expect(text).not_to include("personal journal")
      expect(text).not_to include("飲みすぎちゃった")
      expect(text).to include("English teacher")
    end
  end
end
