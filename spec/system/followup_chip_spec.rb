require "rails_helper"

RSpec.describe "Followup chip on a journal", type: :system do
  # The browser hits the app on another thread. Leave the pinned test
  # connection unlocked so that thread can see the rows this example creates.
  self.lock_threads = false

  # Match production: render public/500.html, which has no followup frame.
  # The local debug page would take over the window instead.
  around do |example|
    env = Rails.application.env_config
    show_exceptions = env["action_dispatch.show_exceptions"]
    detailed = env["action_dispatch.show_detailed_exceptions"]
    env["action_dispatch.show_exceptions"] = :all
    env["action_dispatch.show_detailed_exceptions"] = false
    example.run
  ensure
    env["action_dispatch.show_exceptions"] = show_exceptions
    env["action_dispatch.show_detailed_exceptions"] = detailed
  end

  def create_user
    group = Group.create!(name: "Followup chip #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "followup-chip-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def create_followup_journal(user)
    journal = Journal.create!(title: "Chip journal", user: user, group: user.group, last_interval: 1)
    entry = journal.entries.create!(content: "一行")

    prompt = Prompt.create!(
      type: "FreeQuestionPrompt",
      raw_prompt: "prompt",
      sent_role_prompt: "role",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      base_content: "What is the reading?",
      user_generated_content: "一行"
    )
    Followup.create!(origin: entry, prompt: prompt, source_tag: "ai_assistant")
    query = AiQuery.create!(
      raw_response: {
        answer_1: { content: "negai wish", explanation_en: "Wish or request." }
      }.to_json,
      prompt: prompt,
      journal: journal
    )
    query.ai_outputs.create!(identifier: "1", content: "negai wish", made_note: false)

    journal
  end

  it "shows the saved followup answer in the journal frame" do
    user = create_user
    journal = create_followup_journal(user)

    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Sign in"
    expect(page).to have_current_path(root_path)

    visit journal_path(journal)
    within("turbo-frame#previous_queries") { click_link "F", exact: true }

    frame = find("turbo-frame#followup_output_ai_assistant")
    expect(frame).to have_text("negai wish")
    expect(frame).to have_text("Wish or request.")
    expect(frame).not_to have_css(".turbo-frame-error", text: "Content missing")
    expect(page).to have_current_path(journal_path(journal))
  end
end
