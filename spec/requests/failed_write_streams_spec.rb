require "rails_helper"

RSpec.describe "Failed writes do not render the success stream", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user
    group = Group.create!(name: "Failed write #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "failed-write-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def create_journal(user, title: "Failed write journal")
    Journal.create!(title: title, user: user, group: user.group, last_interval: 1)
  end

  def turbo_stream_headers
    { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def invalid_followup_params(journal)
    {
      followup: {
        source_tag: "ai_assistant",
        followup_origin_class: "Unknown",
        followup_origin_id: "0",
        journal_id: journal.id,
        followup_prompt: {
          base_content: "What does this mean?",
          user_generated_content: "一行",
          raw_prompt: "Followup Question: What does this mean?",
          ai_model: "grok-4-fast-non-reasoning",
          uuid: SecureRandom.uuid
        }
      }
    }
  end

  it "does not close the journal due-date form when the date is blank" do
    user = create_user
    journal = create_journal(user)
    saved_date = journal.reload.next_study_date
    sign_in(user)

    post update_due_date_journal_path(journal),
         params: { next_study_date: "" },
         headers: turbo_stream_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include(%(target="change_journal_due_date_button"))
    expect(response.body).not_to include(%(target="next_review_timestamp"))
    expect(journal.reload.next_study_date).to eq(saved_date)
  end

  it "does not close the note due-date form when the date is blank" do
    user = create_user
    note = user.notes.create!(content: "Failed due date")
    saved_date = note.reload.next_study_date
    sign_in(user)

    post update_due_date_note_path(note),
         params: { next_study_date: "" },
         headers: turbo_stream_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include(%(target="change_journal_due_date_button"))
    expect(response.body).not_to include(%(target="next_review_timestamp"))
    expect(note.reload.next_study_date).to eq(saved_date)
  end

  it "does not remove a journal when mark studied does not save" do
    user = create_user
    journal = create_journal(user)
    sign_in(user)
    allow_any_instance_of(Journal).to receive(:save).and_return(false)

    post mark_journal_as_studied_journal_path(journal), headers: turbo_stream_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include(%(action="remove"))
  end

  it "does not remove a note when mark studied does not save" do
    user = create_user
    note = user.notes.create!(content: "Failed studied note")
    sign_in(user)
    allow_any_instance_of(Note).to receive(:save).and_return(false)

    post mark_note_as_studied_note_path(note), headers: turbo_stream_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include(%(action="remove"))
  end

  it "does not render quiz results or enqueue grading when the prompt does not save" do
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test

    user = create_user
    journal = create_journal(user)
    prompt = PrepareQuizPrompt.create!(
      raw_prompt: "prepare",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    ai_query = AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}")
    quiz = Quiz.create!(journal: journal, ai_query: ai_query)
    sign_in(user)
    allow_any_instance_of(QuizResultPrompt).to receive(:save).and_return(false)

    expect do
      post grade_quiz_journal_quiz_path(journal, quiz), headers: turbo_stream_headers
    end.not_to have_enqueued_job(GradeQuizJob)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include("quiz_results")
  ensure
    ActiveJob::Base.queue_adapter = original_adapter
  end

  it "does not empty the template picker when no template is selected" do
    user = create_user
    sign_in(user)

    delete destroy_selected_followup_template_prompts_path, headers: turbo_stream_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include("template_select")
  end

  it "does not show the followup processing card for an unknown origin" do
    user = create_user
    journal = create_journal(user)
    sign_in(user)

    post followups_path,
         params: invalid_followup_params(journal),
         headers: turbo_stream_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include(I18n.t("ai_query.processing"))
    expect(response.body).not_to include("followup_output_")
  end

  it "redirects an HTML followup create with an unknown origin" do
    user = create_user
    journal = create_journal(user)
    sign_in(user)

    post followups_path, params: invalid_followup_params(journal)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq(I18n.t("followup.invalid_origin"))
  end
end
