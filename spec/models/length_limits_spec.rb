require "rails_helper"

# Entry and note content and quiz answers are limited to 5,000 characters and
# journal titles to 255. Rows that are already longer must stay editable, so
# the limit is only checked when the attribute changes.
RSpec.describe "Length limits", type: :model do
  let(:group) { Group.create!(name: "Limits #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "limits-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:journal) { Journal.create!(title: "Limits", user: user, group: group, last_interval: 1) }

  describe Entry do
    it "accepts content of exactly 5,000 characters" do
      expect(journal.entries.build(content: "a" * 5_000)).to be_valid
    end

    it "refuses content of 5,001 characters" do
      entry = journal.entries.build(content: "a" * 5_001)

      expect(entry).not_to be_valid
      expect(entry.errors.of_kind?(:content, :too_long)).to be(true)
    end

    it "lets an existing over-limit entry be read and saved again, but not made longer" do
      entry = journal.entries.create!(content: "short")
      entry.update_columns(content: "a" * 6_000)
      entry = Entry.find(entry.id)

      expect(entry).to be_valid
      expect(entry.update(position: 1)).to be(true)
      expect(entry.update(content: "a" * 6_001)).to be(false)
      expect(entry.update(content: "back under the limit")).to be(true)
    end
  end

  describe Note do
    it "accepts 5,000 characters and refuses 5,001" do
      expect(user.notes.build(content: "a" * 5_000)).to be_valid
      note = user.notes.build(content: "a" * 5_001)
      expect(note).not_to be_valid
      expect(note.errors.of_kind?(:content, :too_long)).to be(true)
    end

    it "lets an existing over-limit note be saved again until its content changes" do
      note = user.notes.create!(content: "short")
      note.update_columns(content: "a" * 6_000)
      note = Note.find(note.id)

      expect(note).to be_valid
      expect(note.update(content: "a" * 6_001)).to be(false)
    end
  end

  describe Journal do
    it "accepts a title of 255 characters and refuses 256" do
      expect(Journal.new(title: "a" * 255, user: user, group: group, last_interval: 1)).to be_valid
      long = Journal.new(title: "a" * 256, user: user, group: group, last_interval: 1)
      expect(long).not_to be_valid
      expect(long.errors.of_kind?(:title, :too_long)).to be(true)
    end

    it "lets a journal with an existing over-limit title be saved again until the title changes" do
      journal.update_columns(title: "a" * 300)
      journal = Journal.find(self.journal.id)

      expect(journal).to be_valid
      expect(journal.update(last_interval: 2)).to be(true)
      expect(journal.update(title: "b" * 300)).to be(false)
    end
  end

  describe QuizAnswer do
    it "limits user_response to 5,000 characters when it is set" do
      answer = QuizAnswer.new(user_response: "a" * 5_001)
      answer.valid?
      expect(answer.errors.of_kind?(:user_response, :too_long)).to be(true)

      answer = QuizAnswer.new(user_response: "a" * 5_000)
      answer.valid?
      expect(answer.errors.of_kind?(:user_response, :too_long)).to be(false)
    end
  end

  describe "error messages" do
    def message(locale)
      I18n.with_locale(locale) do
        entry = journal.entries.build(content: "a" * 5_001)
        entry.valid?
        entry.errors.full_messages_for(:content).first
      end
    end

    it "are friendly in English" do
      expect(message(:en)).to eq("Content is too long (maximum is 5000 characters).")
    end

    it "are friendly in Japanese" do
      expect(message(:ja)).to eq("Content は5000文字以内で入力してください")
    end
  end
end
