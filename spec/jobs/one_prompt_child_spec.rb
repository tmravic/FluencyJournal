require "rails_helper"

RSpec.describe "one prompt child", type: :job do
  around do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = original
  end

  before do
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
  end

  def create_prompt(type: PrepareQuizPrompt)
    type.create!(
      raw_prompt: "prompt",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
  end

  def create_journal
    group = Group.create!(name: "One child #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "one-child-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    Journal.create!(title: "One child", user: user, group: group, last_interval: 1)
  end

  def create_quiz
    journal = create_journal
    journal.entries.create!(content: "彼女のお母さんに会いました。")
    prepare_prompt = create_prompt
    prepare_query = AiQuery.create!(journal: journal, prompt: prepare_prompt, raw_response: "{}")
    prepare_query.ai_outputs.create!(identifier: "1", content: "PREPARE_QUESTION_ONLY", made_note: false)
    grade_prompt = create_prompt(type: QuizResultPrompt)
    quiz = Quiz.create!(journal: journal, ai_query: prepare_query)

    [ journal, quiz, prepare_query, grade_prompt ]
  end

  def chat_result(body)
    XAiChat::Result.new(
      raw_response: body.to_json,
      parsed: body,
      prompt_tokens: 3,
      completion_tokens: 4,
      total_tokens: 7
    )
  end

  def grade_result
    chat_result(
      "entry_1" => {
        "content" => "会いました → 会いました",
        "explanation_en" => "GRADE_EXPLANATION_UNIQUE"
      },
      "assessment" => "GRADE_ASSESSMENT_UNIQUE"
    )
  end

  it "rejects a second ai query and a second followup for the same prompt" do
    prompt = create_prompt
    AiQuery.create!(prompt: prompt, raw_response: "{}")
    Followup.create!(prompt: prompt, source_tag: "notes_box")

    expect {
      ActiveRecord::Base.transaction(requires_new: true) do
        AiQuery.create!(prompt: prompt, raw_response: "{}")
      end
    }.to raise_error(ActiveRecord::RecordNotUnique)

    expect {
      ActiveRecord::Base.transaction(requires_new: true) do
        Followup.create!(prompt: prompt, source_tag: "notes_box")
      end
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rolls the prepare query back when quiz creation deadlocks" do
    journal = create_journal
    prompt = create_prompt
    allow(XAiChat).to receive(:complete).and_return(chat_result("unused" => "value"))
    allow(Quiz).to receive(:create!).and_raise(ActiveRecord::Deadlocked)

    PrepareQuizJob.perform_now(journal, prompt)

    expect(AiQuery.where(prompt: prompt)).to be_empty

    allow(Quiz).to receive(:create!).and_call_original

    PrepareQuizJob.perform_now(journal, prompt)

    expect(AiQuery.where(prompt: prompt).count).to eq(1)
  end

  it "rolls the grade query back when the grading link deadlocks" do
    journal, quiz, prepare_query, grade_prompt = create_quiz
    allow(XAiChat).to receive(:complete).and_return(grade_result)
    allow(quiz).to receive(:update).and_raise(ActiveRecord::Deadlocked)

    GradeQuizJob.perform_now(journal, grade_prompt, quiz)

    expect(AiQuery.where(prompt: grade_prompt)).to be_empty
    expect(quiz.reload.ai_query).to eq(prepare_query)
    expect(quiz.grading_ai_query).to be_nil

    allow(quiz).to receive(:update).and_call_original

    GradeQuizJob.perform_now(journal, grade_prompt, quiz)

    quiz.reload
    grade_query = quiz.grading_ai_query
    expect(AiQuery.where(prompt: grade_prompt)).to contain_exactly(grade_query)
    expect(quiz.grading_ai_query_id).to eq(grade_query.id)
    expect(quiz.ai_query).to eq(prepare_query)
  end
end
