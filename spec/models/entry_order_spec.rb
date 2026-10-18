require "rails_helper"

RSpec.describe "entry position" do
  def journal_with_user
    group = Group.create!(name: "Order group #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "order-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    Journal.create!(title: "Ordered", user: user, group: group, last_interval: 1)
  end

  it "appends new lines and numbers them by position" do
    journal = journal_with_user
    first = journal.entries.create!(content: "one")
    second = journal.entries.create!(content: "two")
    second.update_column(:created_at, 2.days.ago)

    expect(first.entry_number).to eq(1)
    expect(second.reload.entry_number).to eq(2)
    expect(journal.entries.ordered.map(&:content)).to eq([ "one", "two" ])
    expect(journal.full_journal).to eq([ "one", "two" ])
  end

  it "closes the gap when a line is deleted" do
    journal = journal_with_user
    first = journal.entries.create!(content: "one")
    second = journal.entries.create!(content: "two")
    third = journal.entries.create!(content: "three")

    first.destroy

    expect(second.reload.entry_number).to eq(1)
    expect(third.reload.entry_number).to eq(2)
    expect(journal.full_journal).to eq([ "two", "three" ])
  end

  it "uses the same sequence for a quiz line lookup" do
    journal = journal_with_user
    journal.entries.create!(content: "one")
    second = journal.entries.create!(content: "two")
    output = instance_double(AiOutput, identifier: "2")
    helper = Object.new.extend(QuizAnswerHelper)

    expect(helper.quiz_answer_entry(journal, output)).to eq(second)
  end
end
