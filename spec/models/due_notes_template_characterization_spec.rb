require "rails_helper"

# Pins the due-notes template text before K10 moves it out of
# TemplatePromptConcern. The concern is exercised through a bare host
# object, the way controllers include it.
RSpec.describe "Due notes template (characterization)" do
  let(:host) { Class.new { include TemplatePromptConcern }.new }
  let(:group) { Group.create!(name: "DN #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "dn-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:prefix) { I18n.t("prompt_templates.due_notes_prefix") }
  let(:short) { I18n.t("prompt_templates.due_notes_short") }

  def call(name, *args, **kwargs)
    host.send(name, *args, **kwargs)
  end

  def due_note(content, category: :vocab)
    user.notes.create!(content: content, category: category, next_study_date: 1.day.ago)
  end

  it "offers no due-notes template when nothing is due" do
    user.notes.create!(content: "later", next_study_date: 2.days.from_now)
    due_note("draft", category: :draft_journal)
    FollowupTemplatePrompt.create!(base_content: "Saved template", user: user)

    expect(call(:get_template_prompts_scoped_by_user, user)).to eq([ "Saved template" ])
    expect(call(:expand_due_notes_prompt, short, user)).to be_nil
  end

  it "lists each due note once after the prefix, before the saved templates" do
    due_note("猫")
    due_note("犬")
    due_note("猫")
    FollowupTemplatePrompt.create!(base_content: "Saved template", user: user)

    full = call(:get_template_prompts_scoped_by_user, user)
    expect(full.size).to eq(2)
    expect(full.first).to start_with(prefix)
    expect(full.first.delete_prefix(prefix).split(", ").sort).to eq(%w[犬 猫])
    expect(full.last).to eq("Saved template")
    expect(call(:get_template_prompts_scoped_by_user, user, due_notes_dropdown: :short))
      .to eq([ short, "Saved template" ])
    expect(call(:get_template_prompts_scoped_by_user, user, include_due_notes_template: false))
      .to eq([ "Saved template" ])
  end

  it "cuts a long list to 398 characters plus an ellipsis (401 in all)" do
    due_note("a" * 250)
    due_note("b" * 250)

    text = call(:expand_due_notes_prompt, short, user)
    list = text.delete_prefix(prefix)
    expect(list.length).to eq(401)
    expect(list).to eq(("a" * 250 + ", " + "b" * 250)[0..397] + "...")
  end

  it "keeps a list of exactly 400 characters whole" do
    due_note("a" * 199)
    due_note("b" * 199)

    expect(call(:expand_due_notes_prompt, short, user).delete_prefix(prefix)).to eq("a" * 199 + ", " + "b" * 199)
  end

  it "expands only the short label or a text starting with the prefix, ignoring outer spaces" do
    due_note("猫")
    expected = "#{prefix}猫"

    expect(call(:expand_due_notes_prompt, "  #{short}  ", user)).to eq(expected)
    expect(call(:expand_due_notes_prompt, "#{prefix}stale list", user)).to eq(expected)
    expect(call(:expand_due_notes_prompt, "Something else", user)).to be_nil
    expect(call(:expand_due_notes_prompt, "", user)).to be_nil
    expect(call(:expand_due_notes_prompt, nil, user)).to be_nil
  end
end
