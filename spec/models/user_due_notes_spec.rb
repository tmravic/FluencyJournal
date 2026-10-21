require "rails_helper"

RSpec.describe User, "due notes" do
  let(:group) { Group.create!(name: "UDN #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "udn-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end

  it "counts only this user's notes that are due now, drafts included" do
    user.notes.create!(content: "due", next_study_date: 1.day.ago)
    user.notes.create!(content: "draft due", category: :draft_journal, next_study_date: 1.hour.ago)
    user.notes.create!(content: "later", next_study_date: 1.day.from_now)
    other = User.create!(email_address: "udn-other-#{SecureRandom.hex(4)}@example.com", password: "password",
                         original_language: "English", learning_language: "Japanese", group: group)
    other.notes.create!(content: "theirs", next_study_date: 1.day.ago)

    expect(user.notes_due_count).to eq(2)
    expect(user.no_notes_due?).to be(false)
  end

  it "says no notes are due when none are" do
    user.notes.create!(content: "later", next_study_date: 1.day.from_now)

    expect(user.notes_due_count).to eq(0)
    expect(user.no_notes_due?).to be(true)
  end
end
