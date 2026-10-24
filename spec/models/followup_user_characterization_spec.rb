require "rails_helper"

# Pins Followup#user for every origin type before M6 replaces its type
# chain. The owner is the origin's journal owner, not the signed-in user.
RSpec.describe Followup, "#user (characterization)", type: :model do
  let(:group) { Group.create!(name: "FU #{SecureRandom.hex(4)}") }
  let(:owner) { make_user("owner") }
  let(:viewer) { make_user("viewer") }
  let(:journal) { Journal.create!(title: "Owned", user: owner, group: group, last_interval: 1) }
  let(:entry) { journal.entries.create!(content: "一行目") }

  def make_user(label)
    User.create!(email_address: "fu-#{label}-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end

  def prompt
    FreeQuestionPrompt.create!(raw_prompt: "x", ai_model: "m", uuid: SecureRandom.uuid, sent_role_prompt: "r")
  end

  def followup_on(origin)
    Followup.new(prompt: prompt, origin: origin, source_tag: "ai_assistant")
  end

  def output_on(query_journal)
    query = AiQuery.create!(journal: query_journal, prompt: EntryPrompt.create!(raw_prompt: "x", ai_model: "m", uuid: SecureRandom.uuid, sent_role_prompt: "r"), raw_response: "{}")
    query.ai_outputs.create!(identifier: "1", content: "c", made_note: false)
  end

  around { |example| Current.set(session: nil) { example.run } }

  it "is the journal owner for an entry" do
    expect(followup_on(entry).user).to eq(owner)
  end

  it "is the journal owner for a journal followup" do
    expect(followup_on(journal.journal_followups.create!).user).to eq(owner)
  end

  it "is the note owner for a note" do
    expect(followup_on(owner.notes.create!(content: "n")).user).to eq(owner)
  end

  it "is the query's journal owner for an AI output" do
    expect(followup_on(output_on(journal)).user).to eq(owner)
  end

  it "is nil for an AI output whose query has no journal" do
    expect(followup_on(output_on(nil)).user).to be_nil
  end

  it "falls back to Current.user when there is no origin" do
    allow(Current).to receive(:user).and_return(viewer)

    expect(followup_on(nil).user).to eq(viewer)
  end

  # Bug fix: this used to raise NoMethodError (a Followup had no followup_owner).
  it "is the owner of the parent followup's material for a followup of a followup" do
    parent = Followup.create!(prompt: prompt, origin: entry, source_tag: "ai_assistant")

    expect(followup_on(parent).user).to eq(owner)
  end

  it "follows a chain of followups to the owner" do
    parent = Followup.create!(prompt: prompt, origin: entry, source_tag: "ai_assistant")
    child = Followup.create!(prompt: prompt, origin: parent, source_tag: "ai_assistant")

    expect(followup_on(child).user).to eq(owner)
  end

  it "falls back to Current.user for a followup of a followup whose origin was deleted" do
    allow(Current).to receive(:user).and_return(viewer)
    parent = Followup.create!(prompt: prompt, origin: nil, source_tag: "ai_assistant")

    expect(followup_on(parent).user).to eq(viewer)
  end
end
