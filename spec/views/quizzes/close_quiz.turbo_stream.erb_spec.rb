require "rails_helper"

RSpec.describe "quizzes/close_quiz", type: :view do
  it "restores the compare button with the other header actions" do
    group = Group.create!(name: "Compare group")
    user = User.create!(
      email_address: "close-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Close", user: user, group: group, last_interval: 1)
    journal.entries.create!(content: "一行目")

    assign(:journal, journal)
    assign(:entries, journal.entries.order(:id))
    assign(:source_tag, "ai_assistant")

    render template: "quizzes/close_quiz", formats: [:turbo_stream]

    expect(rendered).to include('target="compare_button"')
    expect(rendered).to include(compare_journal_path(journal))
    expect(rendered).to include(I18n.t("journal.actions.compare"))
  end
end
