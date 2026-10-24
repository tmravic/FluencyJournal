require "rails_helper"
require Rails.root.join("db/migrate/20261024220000_add_unique_index_to_quiz_answers")

RSpec.describe AddUniqueIndexToQuizAnswers do
  # PostgreSQL DDL is transactional, so dropping the index inside the
  # example is rolled back with the rest of it.
  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(direction) }
  end

  def prompt!
    PrepareQuizPrompt.create!(raw_prompt: "p", ai_model: Prompt::DEFAULT_MODEL, uuid: SecureRandom.uuid, sent_role_prompt: "r")
  end

  let(:group) { Group.create!(name: "Migration #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "mig-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:journal) { Journal.create!(title: "Mig", user: user, group: group, last_interval: 1) }
  let(:query) { AiQuery.create!(journal: journal, prompt: prompt!, raw_response: "{}") }
  let(:first) { query.ai_outputs.create!(identifier: "1", content: "One", made_note: false) }
  let(:second) { query.ai_outputs.create!(identifier: "2", content: "Two", made_note: false) }
  let(:quiz) { Quiz.create!(journal: journal, ai_query: query) }
  let(:other_quiz) { Quiz.create!(journal: journal, ai_query: query) }

  def insert_answer(quiz, output, text, at)
    QuizAnswer.new(quiz: quiz, ai_output: output, user_response: text, created_at: at, updated_at: at)
              .tap { |a| a.save!(validate: false) }
  end

  it "keeps the newest answer per quiz and question, then adds the unique index" do
    migrate(:down)
    base = Time.zone.local(2026, 10, 1, 12)
    insert_answer(quiz, first, "old", base)
    newest = insert_answer(quiz, first, "newest", base + 2.minutes)
    insert_answer(quiz, first, "middle", base + 1.minute)
    kept_other_question = insert_answer(quiz, second, "second", base)
    kept_other_quiz = insert_answer(other_quiz, first, "other quiz", base)

    migrate(:up)

    expect(QuizAnswer.where(quiz: quiz, ai_output: first).pluck(:id)).to eq([ newest.id ])
    expect(QuizAnswer.where(id: [ kept_other_question.id, kept_other_quiz.id ]).count).to eq(2)
    expect(QuizAnswer.count).to eq(3)
    expect(ActiveRecord::Base.connection.index_exists?(:quiz_answers, [ :quiz_id, :ai_output_id ], unique: true)).to be(true)
  end

  it "breaks a created_at tie by keeping the highest id" do
    migrate(:down)
    at = Time.zone.local(2026, 10, 1, 12)
    insert_answer(quiz, first, "a", at)
    last = insert_answer(quiz, first, "b", at)

    migrate(:up)

    expect(QuizAnswer.where(quiz: quiz).pluck(:id)).to eq([ last.id ])
  end

  it "rolls back by dropping the index and leaves the rows" do
    quiz.quiz_answers.create!(ai_output: first, user_response: "a")

    migrate(:down)

    expect(ActiveRecord::Base.connection.index_exists?(:quiz_answers, [ :quiz_id, :ai_output_id ])).to be(false)
    expect(QuizAnswer.count).to eq(1)
  end
end
