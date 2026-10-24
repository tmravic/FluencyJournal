require "rails_helper"

RSpec.describe "Successful write redirects", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user
    group = Group.create!(name: "See other #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "see-other-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def create_journal(user, title: "See other journal")
    Journal.create!(title: title, user: user, group: user.group, last_interval: 1)
  end

  def with_test_queue
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    yield
  ensure
    ActiveJob::Base.queue_adapter = original
  end

  it "redirects journal create to the journal with 303" do
    user = create_user
    sign_in(user)

    post journals_path, params: { journal: { title: "Created journal" } }

    journal = user.journals.find_by!(title: "Created journal")
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journal_path(journal))
  end

  it "redirects journal update to the journals index with 303" do
    user = create_user
    journal = create_journal(user)
    sign_in(user)

    patch journal_path(journal), params: { journal: { title: "Updated journal" } }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journals_path)
  end

  it "redirects mark journal as studied to the journal with 303" do
    user = create_user
    journal = create_journal(user)
    sign_in(user)

    post mark_journal_as_studied_journal_path(journal)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journal_path(journal))
  end

  it "redirects entry create to the journal with 303" do
    user = create_user
    journal = create_journal(user)
    sign_in(user)

    post journal_entries_path(journal), params: { entry: { content: "A new line" } }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journal_path(journal))
  end

  it "redirects entry update to the journal with 303" do
    user = create_user
    journal = create_journal(user)
    entry = journal.entries.create!(content: "Original line")
    sign_in(user)

    patch journal_entry_path(journal, entry), params: { entry: { content: "Revised line" } }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journal_path(journal))
  end

  it "redirects note create to the note with 303" do
    user = create_user
    sign_in(user)

    post notes_path, params: { note: { content: "A new note" } }

    note = user.notes.find_by!(content: "A new note")
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(note_path(note))
  end

  it "redirects note update to the journals index with 303" do
    user = create_user
    note = user.notes.create!(content: "Original note", last_interval: 1)
    sign_in(user)

    patch note_path(note), params: { note: { content: "Revised note" } }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journals_path)
  end

  it "redirects mark note as studied to the note with 303" do
    user = create_user
    note = user.notes.create!(content: "Study note", last_interval: 1)
    sign_in(user)

    post mark_note_as_studied_note_path(note)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(note_path(note))
  end

  it "redirects an AI request to the journals index with 303" do
    user = create_user
    journal = create_journal(user)
    sign_in(user)
    allow(AiRequestJob).to receive(:perform_later)

    with_test_queue do
      post ai_request_journal_ai_queries_path(journal), params: {
        entry_prompt: {
          base_content: "Hello",
          user_generated_content: "こんにちは",
          ai_model: "grok-4-fast-non-reasoning",
          uuid: SecureRandom.uuid,
          journal_id: journal.id
        }
      }
    end

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journals_path)
  end

  it "redirects prepare quiz to the journal with 303" do
    user = create_user
    journal = create_journal(user)
    journal.entries.create!(content: "一行目")
    sign_in(user)
    allow(PrepareQuizJob).to receive(:perform_later)

    with_test_queue do
      post prepare_quiz_journal_quizzes_path(journal)
    end

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journal_path(journal))
  end

  it "redirects a successful login with 303" do
    user = create_user

    post session_path, params: { email_address: user.email_address, password: "password" }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(root_url)
  end

  it "keeps a failed login on a 302 to the sign-in page" do
    user = create_user

    post session_path, params: { email_address: user.email_address, password: "wrong" }

    expect(response).to have_http_status(:found)
    expect(response).not_to have_http_status(:see_other)
    expect(response).to redirect_to(new_session_path)
  end
end
