require "spec_helper"

RSpec.describe "block ownership" do
  def component_stylesheet(name)
    root = File.expand_path("..", __dir__)
    File.read(File.join(root, "app/assets/stylesheets/components", name))
  end

  it "does not let the note block own button or form elements" do
    note = component_stylesheet("_note.scss")

    expect(note).not_to include("btn--journal-short")
    expect(note).not_to include(".form__group")
    expect(note).not_to include(".form__actions")
  end

  it "does not let the entry block own form textareas" do
    expect(component_stylesheet("_entry.scss")).not_to include("textarea.form__input")
  end

  it "does not let the followup block own the checkbox label" do
    expect(component_stylesheet("_followup.scss")).not_to include("form__checkbox-label")
  end

  it "keeps the dark journal-short button in the button block" do
    btn = component_stylesheet("_btn.scss")

    expect(btn).to include('[data-theme="dark"]')
    expect(btn).to include(".btn--journal-short")
  end

  it "keeps the stacked form modifier in the form block" do
    expect(component_stylesheet("_form.scss")).to include(".form--stacked")
  end
end
