require "rails_helper"

RSpec.describe "previous row on the list on screen", type: :model do
  def create_user(name)
    group = Group.create!(name: name)
    user = User.create!(
      email_address: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    [ group, user ]
  end

  describe Journal do
    it "returns nil when the relation is nil" do
      _group, user = create_user("Nil journals")
      journal = user.group.journals.create!(title: "Current", user: user, last_interval: 1)

      result = nil
      expect { result = journal.previous_journal(nil) }.not_to raise_error
      expect(result).to be_nil
    end

    it "returns the last earlier journal in the passed relation" do
      group, user = create_user("Study group")
      teammate = User.create!(
        email_address: "teammate-#{SecureRandom.hex(4)}@example.com",
        password: "password",
        original_language: "English",
        learning_language: "Japanese",
        group: group
      )
      other_group, outsider = create_user("Other group")
      now = Time.current
      group.journals.create!(title: "Later", user: user, last_interval: 1, next_study_date: now + 1.day)
      group.journals.create!(title: "Oldest", user: user, last_interval: 1, next_study_date: now - 3.days)
      earlier = group.journals.create!(
        title: "Earlier",
        user: teammate,
        last_interval: 1,
        next_study_date: now - 1.day
      )
      other_group.journals.create!(
        title: "Closer other group",
        user: outsider,
        last_interval: 1,
        next_study_date: now - 1.hour
      )
      current = group.journals.create!(title: "Current", user: user, last_interval: 1, next_study_date: now)
      current.reload

      expect(current.previous_journal(group.journals)).to eq(earlier)
      expect(current.previous_journal(group.journals.ordered)).to eq(earlier)
      expect(current.previous_journal(group.journals.next_to_study)).to eq(earlier)
    end
  end

  describe Note do
    it "returns nil when the relation is nil" do
      _group, user = create_user("Nil notes")
      note = user.notes.create!(content: "Current", last_interval: 1)

      result = nil
      expect { result = note.previous_note(nil) }.not_to raise_error
      expect(result).to be_nil
    end

    it "returns the last earlier note in the passed relation, not a later one" do
      _group, user = create_user("Note order")
      now = Time.current
      user.notes.create!(content: "Later", last_interval: 1, next_study_date: now + 1.day)
      user.notes.create!(content: "Oldest", last_interval: 1, next_study_date: now - 3.days)
      earlier = user.notes.create!(content: "Earlier", last_interval: 1, next_study_date: now - 1.day)
      current = user.notes.create!(content: "Current", last_interval: 1, next_study_date: now)
      current.reload

      expect(current.previous_note(user.notes)).to eq(earlier)
    end

    it "does not return a vocab note when the relation is draft journals" do
      _group, user = create_user("Draft notes")
      now = Time.current
      user.notes.create!(
        content: "Vocab",
        category: :vocab,
        last_interval: 1,
        next_study_date: now - 1.hour
      )
      draft = user.notes.create!(
        content: "Draft",
        category: :draft_journal,
        last_interval: 1,
        next_study_date: now - 1.day
      )
      current = user.notes.create!(
        content: "New draft",
        category: :draft_journal,
        last_interval: 1,
        next_study_date: now
      )
      current.reload

      expect(current.previous_note(user.notes.draft_journal)).to eq(draft)
    end
  end
end
