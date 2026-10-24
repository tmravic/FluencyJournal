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
    expect(journal.entry_texts).to eq([ "one", "two" ])
  end

  it "joins entries in position order for full_text and the journal followup" do
    journal = journal_with_user
    journal.entries.create!(content: "one")
    journal.entries.create!(content: "two")

    expect(journal.full_text).to eq("one\n\ntwo")
    expect(journal.full_text(" ")).to eq("one two")
    expect(JournalFollowup.create!(journal: journal).content).to eq("one\n\ntwo")
  end

  it "closes the gap when a line is deleted" do
    journal = journal_with_user
    first = journal.entries.create!(content: "one")
    second = journal.entries.create!(content: "two")
    third = journal.entries.create!(content: "three")

    first.destroy

    expect(second.reload.entry_number).to eq(1)
    expect(third.reload.entry_number).to eq(2)
    expect(journal.entry_texts).to eq([ "two", "three" ])
  end

  it "uses the same sequence for a quiz line lookup" do
    journal = journal_with_user
    journal.entries.create!(content: "one")
    second = journal.entries.create!(content: "two")
    output = instance_double(AiOutput, line_number: 2)
    helper = Object.new.extend(QuizAnswerHelper)

    expect(helper.quiz_answer_entry(journal, output)).to eq(second)
    expect(journal.entry_at(2)).to eq(second)
  end

  it "lists quiz responses in entry position order" do
    journal = journal_with_user
    journal.entries.create!(content: "one")
    journal.entries.create!(content: "two")
    prompt = Prompt.create!(
      raw_prompt: "grade",
      sent_role_prompt: "role",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid
    )
    query = AiQuery.create!(
      raw_response: "{}",
      prompt: prompt,
      journal: journal,
      prompt_tokens: 1,
      completion_tokens: 1,
      total_tokens: 2
    )
    second = query.ai_outputs.create!(identifier: "2", content: "second question", made_note: false)
    first = query.ai_outputs.create!(identifier: "1", content: "first question", made_note: false)
    quiz = Quiz.create!(ai_query: query, journal: journal)
    quiz.quiz_answers.create!(ai_output: second, user_response: "answer two")
    quiz.quiz_answers.create!(ai_output: first, user_response: "answer one")

    expect(quiz.responses).to eq([ "answer one", "answer two" ])
    expect(second.reload).to be_line
    expect(second.line_number).to eq(2)
  end

  it "treats corrected text and assessment as roles, not line numbers" do
    journal = journal_with_user
    prompt = Prompt.create!(
      raw_prompt: "grade",
      sent_role_prompt: "role",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid
    )
    query = AiQuery.create!(
      raw_response: "{}",
      prompt: prompt,
      journal: journal,
      prompt_tokens: 1,
      completion_tokens: 1,
      total_tokens: 2
    )
    corrected = query.ai_outputs.create!(identifier: "corrected_text", content: "fixed", made_note: false)
    assessment = query.ai_outputs.create!(identifier: "assessment", content: "overall", made_note: false)

    expect(corrected).to be_corrected_text
    expect(assessment).to be_assessment
    expect(corrected.line_number).to be_nil
    expect(assessment.line_number).to be_nil
    expect(query.ai_outputs.corrected_text).to contain_exactly(corrected)
    expect(query.ai_outputs.assessment).to contain_exactly(assessment)
  end
end
