require "rails_helper"

RSpec.describe "Accessible owner", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user(label)
    group = Group.create!(name: "Accessible owner #{label} #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "accessible-#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def create_journal(user, title:)
    Journal.create!(title: title, user: user, group: user.group, last_interval: 1)
  end

  def create_prompt
    FreeQuestionPrompt.create!(
      raw_prompt: "Followup Question: why?",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
  end

  def create_entry(user, title:)
    journal = create_journal(user, title: title)
    entry = journal.entries.create!(content: "line #{title}")
    [ journal, entry ]
  end

  def create_entry_followup(user, title:)
    journal, entry = create_entry(user, title: title)
    followup = Followup.create!(origin: entry, prompt: create_prompt, source_tag: "ai_assistant")
    [ journal, entry, followup ]
  end

  def create_output(query, content:)
    query.ai_outputs.create!(identifier: "1", content: content, made_note: false, role: :line)
  end

  def create_group_query(user, title:)
    journal = create_journal(user, title: title)
    query = AiQuery.create!(journal: journal, prompt: create_prompt, raw_response: "{}")
    output = create_output(query, content: "output #{title}")
    [ journal, query, output ]
  end

  def create_note_followup_query(user)
    note = user.notes.create!(content: "note #{SecureRandom.hex(4)}")
    note.update!(next_study_date: 2.days.from_now)
    prompt = create_prompt
    Followup.create!(origin: note, prompt: prompt, source_tag: "notes_box")
    query = AiQuery.create!(journal: nil, prompt: prompt, raw_response: "{}")
    output = create_output(query, content: "note output")
    [ note, query, output ]
  end

  def followup_params(origin_class:, origin_id:, journal_id:)
    {
      followup: {
        source_tag: "ai_assistant",
        followup_origin_class: origin_class,
        followup_origin_id: origin_id,
        journal_id: journal_id,
        followup_prompt: {
          base_content: "What does this mean?",
          user_generated_content: "reference",
          raw_prompt: "Followup Question: What does this mean?",
          ai_model: "grok-4-fast-non-reasoning",
          uuid: SecureRandom.uuid
        }
      }
    }
  end

  def turbo_headers
    { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def with_test_queue
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    yield
  ensure
    ActiveJob::Base.queue_adapter = original
  end

  it "returns 404 for another group's entry followup and leaves the row" do
    user_a = create_user("a")
    user_b = create_user("b")
    _journal, _entry, followup = create_entry_followup(user_b, title: "Other entry")
    sign_in(user_a)

    get followup_path(followup)

    expect(response).to have_http_status(:not_found)
    expect(Followup.find_by(id: followup.id)).to eq(followup)
  end

  it "returns 404 when deleting another group's entry followup and leaves the row" do
    user_a = create_user("a")
    user_b = create_user("b")
    _journal, _entry, followup = create_entry_followup(user_b, title: "Other delete")
    sign_in(user_a)

    delete followup_path(followup)

    expect(response).to have_http_status(:not_found)
    expect(Followup.find_by(id: followup.id)).to eq(followup)
  end

  it "redirects see_other when deleting this user's entry followup without a journal" do
    user = create_user("owner")
    _journal, _entry, followup = create_entry_followup(user, title: "Own delete")
    sign_in(user)

    delete followup_path(followup)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(root_path)
    expect(Followup.find_by(id: followup.id)).to be_nil
  end

  it "returns 404 for a new followup on another group's entry" do
    user_a = create_user("a")
    user_b = create_user("b")
    _journal, entry = create_entry(user_b, title: "Other new")
    sign_in(user_a)

    get new_followup_path(class_name: "Entry", id: entry.id)

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for a new followup with class name User" do
    user = create_user("owner")
    sign_in(user)

    get new_followup_path(class_name: "User")

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for a followup create with origin class User and does not create a row" do
    user = create_user("owner")
    journal = create_journal(user, title: "User origin")
    sign_in(user)

    with_test_queue do
      expect {
        post followups_path, params: followup_params(
          origin_class: "User",
          origin_id: user.id,
          journal_id: journal.id
        )
      }.not_to change(Followup, :count)
    end

    expect(response).to have_http_status(:not_found)
  end

  it "returns 422 for a followup create with origin class Unknown and does not enqueue a job" do
    user = create_user("owner")
    journal = create_journal(user, title: "Unknown origin")
    sign_in(user)

    with_test_queue do
      expect {
        post followups_path,
             params: followup_params(
               origin_class: "Unknown",
               origin_id: "0",
               journal_id: journal.id
             ),
             headers: turbo_headers
      }.not_to have_enqueued_job(FollowupRequestJob)
    end

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "does not return 404 when creating a followup for this user's entry" do
    user = create_user("owner")
    journal, entry = create_entry(user, title: "Own entry")
    sign_in(user)

    with_test_queue do
      allow(FollowupRequestJob).to receive(:perform_later)

      post followups_path, params: followup_params(
        origin_class: "Entry",
        origin_id: entry.id,
        journal_id: journal.id
      )
    end

    followup = entry.followups.order(:id).last
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(followup_path(followup))
  end

  it "returns 404 when speaking another group's output" do
    user_a = create_user("a")
    user_b = create_user("b")
    _journal, _query, output = create_group_query(user_b, title: "Other speak")
    sign_in(user_a)
    expect(XAiTtsService).not_to receive(:new)

    get speak_ai_output_path(output)

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when deleting another group's output and leaves the row" do
    user_a = create_user("a")
    user_b = create_user("b")
    _journal, _query, output = create_group_query(user_b, title: "Other output")
    sign_in(user_a)

    delete ai_output_path(output)

    expect(response).to have_http_status(:not_found)
    expect(AiOutput.find_by(id: output.id)).to eq(output)
  end

  it "returns 404 for a new automatic note on another group's output and query" do
    user_a = create_user("a")
    user_b = create_user("b")
    _journal, query, output = create_group_query(user_b, title: "Other automatic")
    sign_in(user_a)

    get new_automatic_notes_path(ai_output_id: output.id, ai_query_id: query.id), headers: turbo_headers

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for a new automatic note when the output belongs to a different query" do
    user = create_user("owner")
    _journal, query, _output = create_group_query(user, title: "Mine one")
    _other_journal, _other_query, other_output = create_group_query(user, title: "Mine two")
    sign_in(user)

    get new_automatic_notes_path(ai_output_id: other_output.id, ai_query_id: query.id), headers: turbo_headers

    expect(response).to have_http_status(:not_found)
  end

  it "does not return 404 for a new automatic note on this user's note followup query" do
    user = create_user("owner")
    _note, query, output = create_note_followup_query(user)
    sign_in(user)

    get new_automatic_notes_path(ai_output_id: output.id, ai_query_id: query.id), headers: turbo_headers

    expect(response).not_to have_http_status(:not_found)
    expect(response).to have_http_status(:ok)
  end

  it "returns 404 for a new automatic note on another user's note followup query" do
    user_a = create_user("a")
    user_b = create_user("b")
    _note, query, output = create_note_followup_query(user_b)
    sign_in(user_a)

    get new_automatic_notes_path(ai_output_id: output.id, ai_query_id: query.id), headers: turbo_headers

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for a note create on another group's query and does not save" do
    user_a = create_user("a")
    user_b = create_user("b")
    _journal, query, output = create_group_query(user_b, title: "Other note")
    sign_in(user_a)

    expect {
      post notes_path, params: {
        note: { content: "should not save" },
        ai_query_id: query.id,
        ai_output_identifier: output.identifier
      }
    }.not_to change(Note, :count)

    expect(response).to have_http_status(:not_found)
    expect(output.reload.made_note).to eq(false)
  end

  it "redirects see_other and marks the output when creating a note for this user's query" do
    user = create_user("owner")
    _journal, query, output = create_group_query(user, title: "Own note")
    sign_in(user)

    post notes_path, params: {
      note: { content: "saved from the query" },
      ai_query_id: query.id,
      ai_output_identifier: output.identifier
    }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(note_path(user.notes.order(:id).last))
    expect(output.reload.made_note).to eq(true)
  end

  it "returns 404 when deleting a followup with another group's journal and leaves the row" do
    user_a = create_user("a")
    user_b = create_user("b")
    _journal, _entry, followup = create_entry_followup(user_a, title: "Own with foreign journal")
    other_journal = create_journal(user_b, title: "Foreign journal")
    sign_in(user_a)

    delete followup_path(followup, journal: other_journal.id)

    expect(response).to have_http_status(:not_found)
    expect(Followup.find_by(id: followup.id)).to eq(followup)
  end
end
