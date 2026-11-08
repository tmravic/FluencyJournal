require "rails_helper"

RSpec.describe "journal action components", type: :component do
  def journal
    Journal.new(id: 12, title: "Action journal")
  end

  it "shows listen and the dark exit link while reading" do
    render_inline(ReadingModeButtonComponent.new(journal: journal, reading_mode: true))

    expect(rendered_content).to include(I18n.t("entry.listen"))
    expect(rendered_content).to include("btn--dark")
    expect(rendered_content).to include("reading_mode=false")
    expect(rendered_content).to include('data-controller="tts"')
  end

  it "shows the light enter link when reading mode is off" do
    render_inline(ReadingModeButtonComponent.new(journal: journal, reading_mode: false))

    expect(rendered_content).to include("btn--light")
    expect(rendered_content).to include("reading_mode=true")
    expect(rendered_content).not_to include("btn--dark")
    expect(rendered_content).not_to include('data-controller="tts"')
  end

  it "rejects a locals hash in place of keywords" do
    expect {
      ReadingModeButtonComponent.new(locals: { journal: journal, reading_mode: false })
    }.to raise_error(ArgumentError)
  end

  it "puts from_all_or_todays on the mark-studied path" do
    render_inline(MarkStudiedButtonComponent.new(journal: journal, from_all_or_todays: "todays"))

    expect(rendered_content).to include("from_all_or_todays=todays")
    expect(rendered_content).to include(mark_journal_as_studied_journal_path(journal, from_all_or_todays: "todays"))
  end

  it "omits a blank from_all_or_todays param" do
    render_inline(MarkStudiedButtonComponent.new(journal: journal, from_all_or_todays: nil))

    expect(rendered_content).not_to include("from_all_or_todays")
  end
end
