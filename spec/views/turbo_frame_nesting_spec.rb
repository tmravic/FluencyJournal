require "rails_helper"

RSpec.describe "turbo frame ids", type: :view do
  def stream_template(html, target, action = "update")
    html[/action="#{Regexp.escape(action)}" target="#{Regexp.escape(target)}"><template>(.*?)<\/template>/m, 1].to_s
  end

  def journal_with_entry
    group = Group.create!(name: "Frame group #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "frame-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Frame", user: user, group: group, last_interval: 1)
    journal.entries.create!(content: "一行目")
    journal
  end

  it "fills #entries without rendering that frame again" do
    journal = journal_with_entry
    assign(:reading_mode, false)
    assign(:journal, journal)
    assign(:entries, journal.entries.order(:id))
    assign(:source_tag, "ai_assistant")

    render template: "journals/reading_mode", formats: [:turbo_stream]

    body = stream_template(rendered, "entries")
    expect(body).to include("一行目")
    expect(body).not_to include('id="entries"')

    render partial: "entries/entries_frame"
    expect(rendered.scan('id="entries"').size).to eq(1)
  end

  it "fills a quiz entry without rendering that frame again" do
    journal = journal_with_entry
    prompt = Prompt.create!(
      raw_prompt: "prompt",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    query = AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}")
    output = query.ai_outputs.create!(identifier: "1", content: "line", made_note: false)
    quiz = Quiz.create!(journal: journal, ai_query: query)
    frame_id = ActionView::RecordIdentifier.dom_id(output)

    assign(:quiz_entry_frame, frame_id)
    assign(:journal, journal)
    assign(:quiz, quiz)
    assign(:ai_output, output)
    assign(:identifier, output.identifier)
    assign(:entry_content, "一行目")
    assign(:entry, journal.entries.order(:id).first)

    render template: "quizzes/peek", formats: [:turbo_stream]

    body = stream_template(rendered, frame_id)
    expect(body).to include("一行目")
    expect(body).to include(I18n.t("go_back"))
    expect(body).not_to include(%(id="#{frame_id}"))

    assign(:frame, frame_id)
    assign(:ai_output, output)
    render template: "quizzes/unpeek", formats: [:turbo_stream]

    restored = stream_template(rendered, frame_id)
    expect(restored).to include(I18n.t("entry.entry", number: "1"))
    expect(restored).not_to include(%(id="#{frame_id}"))
    expect(restored).to include(%(id="hint_entry_#{output.id}"))
  end

  it "renders the note due-date frame once" do
    journal = journal_with_entry
    note = journal.user.notes.create!(content: "単語")

    assign(:source_tag, "notes_box")
    assign(:todays_notes, Note.none)
    render partial: "notes/note_display", locals: { note: note, source_tag: "notes_box" }

    frame_id = "change_note_due_date_#{note.id}"
    expect(rendered.scan(%(id="#{frame_id}")).size).to eq(1)

    assign(:note, note)
    render template: "notes/update_due_date", formats: [:turbo_stream]

    body = stream_template(rendered, frame_id)
    expect(body).to include(change_due_date_note_path(note))
    expect(body).not_to include("turbo-frame")
  end

  it "replaces #workspace instead of nesting that frame" do
    journal = journal_with_entry
    assign(:journal, journal)
    assign(:from_all_or_todays, "todays")
    assign(:entries, journal.entries.order(:id))
    assign(:reading_mode, false)
    assign(:source_tag, "ai_assistant")

    render template: "journals/create", formats: [:turbo_stream]

    expect(rendered).to include('action="replace" target="workspace"')
    expect(rendered).not_to include('action="update" target="workspace"')
    body = stream_template(rendered, "workspace", "replace")
    expect(body.scan('id="workspace"').size).to eq(1)
  end

  it "replaces #template_select instead of nesting that frame" do
    assign(:followup_template_prompts, [ "A saved prompt" ])
    # The stream names the partial the way the template-prompts controller does.
    controller.lookup_context.prefixes.unshift("followup_template_prompts")

    render template: "followup_template_prompts/destroy_selected", formats: [:turbo_stream]

    expect(rendered).to include('action="replace" target="template_select"')
    expect(rendered).not_to include('action="update" target="template_select"')
    body = stream_template(rendered, "template_select", "replace")
    expect(body.scan('id="template_select"').size).to eq(1)
  end
end
