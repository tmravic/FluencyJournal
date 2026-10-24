require "rails_helper"

RSpec.describe "journals/_journal", type: :view do
  let(:group) { Group.create!(name: "Card view #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "card-view-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:journal) { Journal.create!(title: "Card view", user: user, group: group, last_interval: 1) }

  def render_card(mode)
    render partial: "journals/journal", locals: { journal: journal, mode: mode }
    rendered
  end

  it "shows the Studied button and todays links in :todays mode" do
    html = render_card(:todays)

    expect(html).to include("mark_journal_as_studied")
    expect(html).not_to include(I18n.t("note.next_review"))
    expect(html).to include("from_all_or_todays=todays")
  end

  it "shows the next review date and all links in :all mode" do
    html = render_card(:all)

    expect(html).not_to include("mark_journal_as_studied")
    expect(html).to include(I18n.t("note.next_review"))
    expect(html).to include("from_all_or_todays=all")
  end

  it "shows neither in :none mode" do
    html = render_card(:none)

    expect(html).not_to include("mark_journal_as_studied")
    expect(html).not_to include(I18n.t("note.next_review"))
    expect(html).to include("from_all_or_todays=all")
  end

  it "does not read the page's instance variables" do
    assign(:todays_journals, [ journal ])
    assign(:all_journals, [ journal ])

    expect(render_card(:none)).not_to include("mark_journal_as_studied")
  end
end
