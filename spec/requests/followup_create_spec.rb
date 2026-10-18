require "rails_helper"

RSpec.describe "POST /followups", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_entry
    group = Group.create!(name: "Followup create #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "followup-create-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Followup journal", user: user, group: group, last_interval: 1)
    entry = journal.entries.create!(content: "一行目")
    [ user, entry ]
  end

  def followup_params(entry)
    {
      followup: {
        source_tag: "ai_assistant",
        followup_origin_class: "Entry",
        followup_origin_id: entry.id,
        followup_prompt: {
          base_content: "What does this mean?",
          user_generated_content: entry.content,
          ai_model: "grok-4-fast-non-reasoning",
          uuid: SecureRandom.uuid
        }
      }
    }
  end

  it "redirects an HTML create to the saved followup" do
    user, entry = create_entry
    sign_in(user)

    post followups_path, params: followup_params(entry)

    followup = Followup.order(:id).last
    expect(followup.origin).to eq(entry)
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(followup_path(followup))
    expect(flash[:notice]).to eq(I18n.t("followup.request_sent"))
  end

  it "keeps the Turbo create on the processing stream" do
    user, entry = create_entry
    sign_in(user)

    post followups_path,
         params: followup_params(entry),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    followup = Followup.order(:id).last
    expect(followup.origin).to eq(entry)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include("followup_output_ai_assistant")
    expect(response.body).to include(I18n.t("ai_query.processing"))
  end
end
