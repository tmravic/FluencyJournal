require "rails_helper"

RSpec.describe "Closing the AI assistant during a rewrite", type: :system do
  # The browser hits the app on another thread. Leave the pinned test
  # connection unlocked so that thread can see the rows this example creates.
  self.lock_threads = false

  # The Close button arrives on the assistant's cable stream. The test
  # adapter records broadcasts and does not deliver them, so this example
  # uses the in-process async adapter before the page connects.
  around do |example|
    server = ActionCable.server
    pubsub = server.pubsub
    forgery = server.config.disable_request_forgery_protection
    server.config.disable_request_forgery_protection = true
    server.instance_variable_set(:@pubsub, ActionCable::SubscriptionAdapter::Async.new(server))
    example.run
  ensure
    server.config.disable_request_forgery_protection = forgery
    server.instance_variable_set(:@pubsub, pubsub)
  end

  def create_user
    group = Group.create!(name: "Rewrite close #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "rewrite-close-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def create_answered_query(journal)
    prompt = Prompt.create!(
      type: "EntryPrompt",
      raw_prompt: "prompt",
      sent_role_prompt: "role",
      ai_model: Prompt::DEFAULT_MODEL,
      uuid: SecureRandom.uuid,
      base_content: "hello",
      user_generated_content: "Parent line"
    )
    AiQuery.create!(raw_response: "{}", prompt: prompt, journal: journal)
  end

  it "keeps the parent journal on screen" do
    user = create_user
    journal = Journal.create!(title: "Rewrite close", user: user, group: user.group, last_interval: 1)
    journal.entries.create!(content: "Parent line")

    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Sign in"
    expect(page).to have_current_path(root_path)

    visit journal_path(journal)
    click_button "Rewrite"
    expect(page).to have_css("#entries .compare-results", text: "Parent line")

    click_link "Open AI Assistant"
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)
    rewrite = journal.rewrites.order(:id).last
    ai_query = create_answered_query(rewrite)
    uuid = find("[name='entry_prompt[uuid]']", visible: :all).value

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{uuid}",
      target: "ai_request_form_delete_buttons",
      partial: "ai_queries/delete_buttons",
      locals: { journal: rewrite, ai_query: ai_query }
    )

    within("turbo-frame#ai_request_form_delete_buttons") { click_link "Close", exact: true }

    expect(page).to have_no_link("Close", exact: true)
    expect(page).to have_css("#entries .compare-results", text: "Parent line")
    expect(page).to have_current_path(journal_path(journal))
  end
end
