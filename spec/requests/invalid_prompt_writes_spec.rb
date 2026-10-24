require "rails_helper"

# A prompt that fails validation must answer 422 without raising, and must
# not enqueue the AI job.
RSpec.describe "Invalid prompt writes", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user
    group = Group.create!(name: "Invalid prompt #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "invalid-prompt-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def create_journal(user)
    Journal.create!(title: "Invalid prompt journal", user: user, group: user.group, last_interval: 1)
  end

  def turbo_stream_headers
    { "Accept" => "text/vnd.turbo-stream.html" }
  end

  it "answers 422 for a followup whose prompt has no model" do
    user = create_user
    journal = create_journal(user)
    entry = journal.entries.create!(content: "一行")
    sign_in(user)
    expect(FollowupRequestJob).not_to receive(:perform_later)

    expect {
      post followups_path,
           params: {
             followup: {
               source_tag: "ai_assistant",
               followup_origin_class: "Entry",
               followup_origin_id: entry.id,
               journal_id: journal.id,
               followup_prompt: {
                 base_content: "What does this mean?",
                 user_generated_content: "一行",
                 ai_model: "",
                 uuid: SecureRandom.uuid
               }
             }
           },
           headers: turbo_stream_headers
    }.not_to change { [ Prompt.count, Followup.count ] }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to be_empty
  end
end
