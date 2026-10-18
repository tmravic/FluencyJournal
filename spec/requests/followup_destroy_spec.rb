require "rails_helper"

RSpec.describe "DELETE /followups/:id", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user
    group = Group.create!(name: "Followup delete #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "followup-delete-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def create_prompt
    Prompt.create!(
      type: "FreeQuestionPrompt",
      raw_prompt: "Followup Question: why?",
      sent_role_prompt: "role",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      base_content: "why?",
      user_generated_content: "一行"
    )
  end

  it "removes the followup, the prompt, and the answer over Turbo" do
    user = create_user
    journal = Journal.create!(title: "Delete", user: user, group: user.group, last_interval: 1)
    entry = journal.entries.create!(content: "一行")
    prompt = create_prompt
    followup = Followup.create!(origin: entry, prompt: prompt, source_tag: "ai_assistant")
    answer = AiQuery.create!(raw_response: "{}", prompt: prompt, journal: journal)
    answer.ai_outputs.create!(identifier: "1", content: "カード", made_note: false, role: :line)

    sign_in(user)
    delete followup_path(followup, source_tag: "ai_assistant", journal: journal.id),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("previous_queries")
    expect(response.body).not_to include(followup_path(followup))
    expect(Followup.find_by(id: followup.id)).to be_nil
    expect(Prompt.find_by(id: prompt.id)).to be_nil
    expect(AiQuery.find_by(id: answer.id)).to be_nil
  end

  it "redirects an HTML delete after the rows are gone" do
    user = create_user
    journal = Journal.create!(title: "Delete", user: user, group: user.group, last_interval: 1)
    entry = journal.entries.create!(content: "一行")
    prompt = create_prompt
    followup = Followup.create!(origin: entry, prompt: prompt, source_tag: "ai_assistant")
    AiQuery.create!(raw_response: "{}", prompt: prompt, journal: journal)

    sign_in(user)
    delete followup_path(followup, source_tag: "ai_assistant", journal: journal.id)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journal_path(journal))
    expect(Followup.find_by(id: followup.id)).to be_nil
    expect(Prompt.find_by(id: prompt.id)).to be_nil
  end

  it "leaves the note chip out of the notes list" do
    user = create_user
    note = user.notes.create!(content: "覚悟", next_study_date: Time.current)
    prompt = create_prompt
    followup = Followup.create!(origin: note, prompt: prompt, source_tag: "notes_box")
    AiQuery.create!(raw_response: "{}", prompt: prompt)

    sign_in(user)
    delete followup_path(followup, source_tag: "notes_box"),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("覚悟")
    expect(response.body).not_to include(followup_path(followup, source_tag: "notes_box"))
    expect(Followup.find_by(id: followup.id)).to be_nil
    expect(Note.find_by(id: note.id)).to eq(note)
  end

  it "does not remove the followup from the page when the delete returns false" do
    user = create_user
    journal = Journal.create!(title: "Delete", user: user, group: user.group, last_interval: 1)
    entry = journal.entries.create!(content: "一行")
    prompt = create_prompt
    followup = Followup.create!(origin: entry, prompt: prompt, source_tag: "ai_assistant")
    allow_any_instance_of(Followup).to receive(:destroy).and_return(false)

    sign_in(user)
    delete followup_path(followup, source_tag: "ai_assistant", journal: journal.id),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include("previous_queries")
    expect(Followup.find_by(id: followup.id)).to eq(followup)
    expect(Prompt.find_by(id: prompt.id)).to eq(prompt)
  end

  it "redirects an HTML delete with an alert when the delete returns false" do
    user = create_user
    journal = Journal.create!(title: "Delete", user: user, group: user.group, last_interval: 1)
    entry = journal.entries.create!(content: "一行")
    prompt = create_prompt
    followup = Followup.create!(origin: entry, prompt: prompt, source_tag: "ai_assistant")
    allow_any_instance_of(Followup).to receive(:destroy).and_return(false)

    sign_in(user)
    delete followup_path(followup, source_tag: "ai_assistant", journal: journal.id)

    expect(response).to redirect_to(journal_path(journal))
    expect(flash[:alert]).to eq(I18n.t("followup.delete_failed"))
    expect(Followup.find_by(id: followup.id)).to eq(followup)
  end

  it "does not remove the followup from the page when the prompt delete fails" do
    user = create_user
    journal = Journal.create!(title: "Delete", user: user, group: user.group, last_interval: 1)
    entry = journal.entries.create!(content: "一行")
    prompt = create_prompt
    followup = Followup.create!(origin: entry, prompt: prompt, source_tag: "ai_assistant")
    AiQuery.create!(raw_response: "{}", prompt: prompt, journal: journal)
    allow_any_instance_of(Prompt).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)

    sign_in(user)
    delete followup_path(followup, source_tag: "ai_assistant", journal: journal.id),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include("previous_queries")
    expect(Followup.find_by(id: followup.id)).to eq(followup)
    expect(Prompt.find_by(id: prompt.id)).to eq(prompt)
  end
end
