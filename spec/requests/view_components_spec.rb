require "rails_helper"

RSpec.describe "ViewComponent pages", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user
    group = Group.create!(name: "Component group #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "component-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def turbo_stream_headers
    { "Accept" => "text/vnd.turbo-stream.html" }
  end

  it "renders the journal action row when the journal has an entry" do
    user = create_user
    journal = Journal.create!(title: "Action row", user: user, group: user.group, last_interval: 1)
    journal.entries.create!(content: "One line")
    sign_in(user)

    get journal_path(journal)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(id="quiz_buttons"))
    expect(response.body).to include(prepare_quiz_journal_quizzes_path(journal))
    expect(response.body).to include(mark_journal_as_studied_journal_path(journal))
    expect(response.body).to include(I18n.t("journal.actions.quiz_me"))
    expect(response.body).to include(I18n.t("journal.actions.reading_mode"))
    expect(response.body).to include("followup_output_ai_assistant")
  end

  it "leaves the quiz and reading-mode buttons off a journal with no entries" do
    user = create_user
    journal = Journal.create!(title: "Empty journal", user: user, group: user.group, last_interval: 1)
    sign_in(user)

    get journal_path(journal)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(open_ai_assistant_journal_path(journal))
    expect(response.body).not_to include(prepare_quiz_journal_quizzes_path(journal))
    expect(response.body).not_to include(reading_mode_journal_path(journal, reading_mode: true))
  end

  it "renders today's note header when a note is due" do
    user = create_user
    user.notes.create!(content: "Due word")
    sign_in(user)

    get notes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('class="note__header"')
    expect(response.body).to include(ERB::Util.html_escape(I18n.t("note.todays_notes")))
    expect(response.body).to include("view_context=todays_notes")
    expect(response.body).to include(%(id="due_today_notes_count"))
  end

  it "leaves the note header off an empty today list" do
    user = create_user
    sign_in(user)

    get notes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('class="note__header"')
    expect(response.body).to include(ERB::Util.html_escape(I18n.t("note.empty_state_due")))
  end

  it "renders the all, drafts, and journal note headers" do
    user = create_user
    journal = Journal.create!(title: "Linked journal", user: user, group: user.group, last_interval: 1)
    note = user.notes.create!(content: "Draft line", category: :draft_journal)
    note.journals << journal
    sign_in(user)

    get all_notes_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('class="note__header"')
    expect(response.body).to include("view_context=all_notes")

    get drafts_notes_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("note.draft_journals"))
    expect(response.body).to include("view_context=draft_notes")

    get for_journal_notes_path(journal_id: journal.id)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(ERB::Util.html_escape(I18n.t("note.linked_to_journal", title: journal.title)))
    expect(response.body).not_to include("view_context=")
  end

  it "appends a today's note and refreshes that header" do
    user = create_user
    sign_in(user)

    post notes_path,
         params: {
           view_context: "todays_notes",
           note: { content: "Fresh word", category: "vocab" }
         },
         headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(action="append" target="notes"))
    expect(response.body).not_to include(%(action="after"))
    expect(response.body).to include(%(target="note_header"))
    expect(response.body).to include(ERB::Util.html_escape(I18n.t("note.todays_notes")))
    expect(response.body).to include("view_context=todays_notes")
  end

  it "saves a note with an unknown list and leaves the header alone" do
    user = create_user
    sign_in(user)

    expect {
      post notes_path,
           params: {
             view_context: "elsewhere",
             note: { content: "Loose note", category: "vocab" }
           },
           headers: turbo_stream_headers
    }.to change(Note, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(%(target="note_header"))
    expect(response.body).not_to include(%(target="notes"))
  end
end
