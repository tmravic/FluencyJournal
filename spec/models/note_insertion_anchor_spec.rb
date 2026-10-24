require "rails_helper"

RSpec.describe Note, "#insertion_anchor_in" do
  include ActiveSupport::Testing::TimeHelpers

  let(:group) { Group.create!(name: "Anchor #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "anchor-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end

  it "sets the study date and returns the last earlier note in the list" do
    travel_to(Time.zone.local(2026, 1, 1, 12)) do
      older = user.notes.create!(content: "older", next_study_date: 2.days.ago)
      user.notes.create!(content: "later", next_study_date: 1.day.from_now)
      note = user.notes.build(content: "new")

      expect(note.next_study_date).to be_nil
      expect(note.insertion_anchor_in(user.notes.reorder(:next_study_date))).to eq(older)
      expect(note.next_study_date).to eq(Time.current)
    end
  end

  it "returns nil when the list is empty" do
    expect(user.notes.build(content: "new").insertion_anchor_in(user.notes.none)).to be_nil
  end
end
