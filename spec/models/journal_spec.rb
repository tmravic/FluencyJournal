require "rails_helper"

RSpec.describe Journal, type: :model do
  def create_user(label)
    group = Group.create!(name: "Journal #{label} #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "journal-#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  it "refuses a second journal with the same title for the same user" do
    user = create_user("same")
    Journal.create!(title: "Birthday", user: user, group: user.group, last_interval: 1)
    duplicate = Journal.new(title: "Birthday", user: user, group: user.group, last_interval: 1)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors.of_kind?(:title, :taken)).to be(true)
    I18n.with_locale(:ja) do
      duplicate.valid?
      expect(duplicate.errors.full_messages_for(:title).first).to eq("題名はすでに存在します")
    end
  end

  it "allows the same title for a different user" do
    first = create_user("first")
    second = create_user("second")
    Journal.create!(title: "Birthday", user: first, group: first.group, last_interval: 1)
    other = Journal.new(title: "Birthday", user: second, group: second.group, last_interval: 1)

    expect(other).to be_valid
  end

  it "names rewrites with the parent title and the next free number" do
    user = create_user("rewrite")
    journal = Journal.create!(title: "Birthday", user: user, group: user.group, last_interval: 1)
    Journal.create!(title: "Birthday (1)", user: user, group: user.group, last_interval: 1)

    first = journal.writing_rewrite
    second = journal.writing_rewrite
    first.destroy!

    expect(first.title).to eq("Birthday (2)")
    expect(second.title).to eq("Birthday (3)")
    expect(journal.writing_rewrite.title).to eq("Birthday (2)")
    expect(journal.mark_studied).to be(true)
  end

  it "keeps a numbered rewrite title within the title limit" do
    user = create_user("long")
    journal = Journal.create!(
      title: "あ" * Journal::MAX_TITLE_LENGTH,
      user: user,
      group: user.group,
      last_interval: 1
    )

    rewrite = journal.writing_rewrite

    expect(rewrite.title.length).to be <= Journal::MAX_TITLE_LENGTH
    expect(rewrite.title).to end_with(" (1)")
  end
end
