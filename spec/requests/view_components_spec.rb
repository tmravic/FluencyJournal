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
    expect(response.body).to include(mark_journal_as_studied_journal_path(journal))
    expect(response.body).to include(I18n.t("journal.actions.reading_mode"))
    expect(response.body).to include(I18n.t("journal.actions.rewrite"))
    expect(response.body).to include(%(id="rewrite_button"))
    expect(response.body).to include("followup_output_ai_assistant")
  end

  it "leaves the reading-mode button off a journal with no entries" do
    user = create_user
    journal = Journal.create!(title: "Empty journal", user: user, group: user.group, last_interval: 1)
    sign_in(user)

    get journal_path(journal)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(open_ai_assistant_journal_path(journal))
    expect(response.body).not_to include(reading_mode_journal_path(journal, reading_mode: true))
  end

  it "hides Rewrite in English while reading and brings it back after" do
    user = create_user
    journal = Journal.create!(title: "Reading", user: user, group: user.group, last_interval: 1)
    journal.entries.create!(content: "One line")
    sign_in(user)

    get reading_mode_journal_path(journal, reading_mode: true), headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(target="rewrite_button"))
    expect(response.body).not_to include(I18n.t("journal.actions.rewrite"))

    get reading_mode_journal_path(journal, reading_mode: false), headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(target="rewrite_button"))
    expect(response.body).to include(I18n.t("journal.actions.rewrite"))
  end

  it "opens a child journal and points Start Entry and the assistant at it" do
    user = create_user
    journal = Journal.create!(title: "Rewrite", user: user, group: user.group, last_interval: 1)
    journal.entries.create!(content: "One line")
    sign_in(user)

    expect {
      post journal_rewrites_path(journal), headers: turbo_stream_headers
    }.to change(Journal, :count).by(1)

    first_rewrite = journal.rewrites.sole
    expect(first_rewrite.source_journal).to eq(journal)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(target="entries"))
    expect(response.body).to include(%(target="new_entry"))
    expect(response.body).to include(ERB::Util.html_escape(I18n.t("entry.empty_state")))
    expect(response.body).to include(new_journal_entry_path(first_rewrite))
    expect(response.body).to include(open_ai_assistant_journal_path(first_rewrite))
    expect(response.body).to include(original_journal_rewrites_path(journal))
    expect(response.body).to include(journal_rewrite_path(journal, first_rewrite))
    expect(response.body).to include(I18n.t("journal.rewrites"))
    expect(response.body).not_to include(I18n.t("journal.actions.reading_mode"))
    expect(response.body).not_to include(I18n.t("journal.actions.mark_studied"))
    expect(response.body).not_to include(I18n.t("journal.actions.change_date"))
    expect(response.body).to include("compare-results")
    expect(response.body).to include("One line")

    expect {
      post journal_rewrites_path(journal), headers: turbo_stream_headers
    }.to change(Journal, :count).by(1)

    second_rewrite = journal.rewrites.order(:id).last
    expect(response.body).to include(journal_rewrite_path(journal, first_rewrite))
    expect(response.body).to include(journal_rewrite_path(journal, second_rewrite))
  end

  it "keeps the parent journal on screen when starting a rewrite entry" do
    user = create_user
    journal = Journal.create!(title: "Source", user: user, group: user.group, last_interval: 1)
    journal.entries.create!(content: "Parent line")
    sign_in(user)
    post journal_rewrites_path(journal), headers: turbo_stream_headers
    rewrite = journal.rewrites.sole

    get new_journal_entry_path(rewrite), headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="entry[content]"')
    expect(response.body).not_to include(%(target="entries"))
  end

  it "opens the entries of the rewrite whose chip was clicked" do
    user = create_user
    journal = Journal.create!(title: "Rewrite", user: user, group: user.group, last_interval: 1)
    sign_in(user)
    post journal_rewrites_path(journal), headers: turbo_stream_headers
    post journal_rewrites_path(journal), headers: turbo_stream_headers
    first_rewrite, second_rewrite = journal.rewrites.order(:id).to_a
    first_rewrite.entries.create!(content: "First rewrite line")
    second_rewrite.entries.create!(content: "Second rewrite line")

    get journal_rewrite_path(journal, first_rewrite), headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("First rewrite line")
    expect(response.body).to include(new_journal_entry_path(first_rewrite))
    expect(response.body).not_to include("Second rewrite line")
  end

  it "returns to the original journal and restores the hidden buttons" do
    user = create_user
    journal = Journal.create!(title: "Rewrite", user: user, group: user.group, last_interval: 1)
    journal.entries.create!(content: "One line")
    sign_in(user)
    post journal_rewrites_path(journal), headers: turbo_stream_headers

    get original_journal_rewrites_path(journal), headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("One line")
    expect(response.body).to include(new_journal_entry_path(journal))
    expect(response.body).to include(open_ai_assistant_journal_path(journal))
    expect(response.body).to include(I18n.t("journal.actions.reading_mode"))
    expect(response.body).to include(I18n.t("journal.actions.mark_studied"))
    expect(response.body).to include(I18n.t("journal.actions.change_date"))
    expect(response.body).to include(journal_rewrites_path(journal))
    expect(response.body).not_to include(original_journal_rewrites_path(journal))
    expect(journal.rewrites).to be_empty
  end

  it "deletes empty rewrites and keeps rewrites that have entries" do
    user = create_user
    journal = Journal.create!(title: "Rewrite", user: user, group: user.group, last_interval: 1)
    sign_in(user)
    post journal_rewrites_path(journal), headers: turbo_stream_headers
    post journal_rewrites_path(journal), headers: turbo_stream_headers
    kept, empty = journal.rewrites.order(:id).to_a
    kept.entries.create!(content: "Kept line")

    get original_journal_rewrites_path(journal), headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(journal.rewrites.reload).to contain_exactly(kept)
    expect(response.body).to include(journal_rewrite_path(journal, kept))
    expect(response.body).not_to include(journal_rewrite_path(journal, empty))
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
