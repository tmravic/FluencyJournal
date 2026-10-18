require "rails_helper"

RSpec.describe Followup, type: :model do
  def create_user
    group = Group.create!(name: "Followup link #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "followup-link-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def create_prompt(type: "FreeQuestionPrompt")
    Prompt.create!(
      type: type,
      raw_prompt: "Followup Question: why?",
      sent_role_prompt: "role",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid
    )
  end

  def create_followup(origin, prompt = create_prompt)
    described_class.create!(origin: origin, prompt: prompt, source_tag: "notes_box")
  end

  it "lists a note's followups from the origin link" do
    user = create_user
    note = user.notes.create!(content: "覚悟")
    other = user.notes.create!(content: "別のノート")
    followup = create_followup(note)

    expect(note.followups).to contain_exactly(followup)
    expect(other.followups).to be_empty
    expect(Note.includes(:followups).find(note.id).followups).to contain_exactly(followup)
  end

  it "lists an entry's followups from the origin link" do
    user = create_user
    journal = Journal.create!(title: "Journal", user: user, group: user.group, last_interval: 1)
    entry = journal.entries.create!(content: "一行")
    followup = create_followup(entry)

    expect(entry.followups).to contain_exactly(followup)
    expect(followup.origin).to eq(entry)
  end

  it "lists an output's followups from the origin link" do
    user = create_user
    journal = Journal.create!(title: "Journal", user: user, group: user.group, last_interval: 1)
    prompt = create_prompt(type: "EntryPrompt")
    query = AiQuery.create!(raw_response: "{}", prompt: prompt, journal: journal)
    output = query.ai_outputs.create!(identifier: "1", content: "カード", made_note: false, role: :line)
    followup = create_followup(output)

    expect(output.followups).to contain_exactly(followup)
    expect(query.followups).to be_empty
    expect(query.prompt.followup).to be_nil
    expect(followup.prompt.followup).to eq(followup)
  end

  it "keeps the answer query off the origin association" do
    user = create_user
    journal = Journal.create!(title: "Journal", user: user, group: user.group, last_interval: 1)
    entry = journal.entries.create!(content: "一行")
    prompt = create_prompt
    followup = create_followup(entry, prompt)
    answer = AiQuery.create!(raw_response: "{}", prompt: prompt, journal: journal)

    expect(answer.prompt.followup).to eq(followup)
    expect(answer.followups).to be_empty
    expect(entry.reload.followups).to contain_exactly(followup)
  end

  it "has dropped the join tables" do
    tables = ActiveRecord::Base.connection.tables

    expect(tables).not_to include("entries_followups")
    expect(tables).not_to include("followups_notes")
    expect(tables).not_to include("ai_outputs_followups")
    expect(tables).not_to include("ai_queries_followups")
  end
end
