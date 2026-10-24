require "rails_helper"

RSpec.describe "Theme toggle", type: :system do
  # The label script sets aria-label after the page loads. It used to write
  # English text for every locale.
  it "labels the button in the page language after the script runs" do
    visit new_session_path(locale: "ja")

    expect(page).to have_css(%(button.theme-toggle[aria-label="#{I18n.t("theme.switch_to_dark", locale: :ja)}"]))

    find("button.theme-toggle").click

    expect(page).to have_css(%(button.theme-toggle[aria-label="#{I18n.t("theme.switch_to_light", locale: :ja)}"]))
  end

  it "keeps the English labels for English pages" do
    visit new_session_path(locale: "en")

    expect(page).to have_css(%(button.theme-toggle[aria-label="Switch to dark mode"]))
  end
end
