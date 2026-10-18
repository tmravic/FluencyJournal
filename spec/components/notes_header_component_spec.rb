require "rails_helper"

RSpec.describe NotesHeaderComponent, type: :component do
  def escaped(key, **)
    ERB::Util.html_escape(I18n.t(key, **))
  end

  it "renders today's heading and the new-note context" do
    render_inline(described_class.new(list: "todays_notes"))

    expect(rendered_content).to include(escaped("note.todays_notes"))
    expect(rendered_content).to include("view_context=todays_notes")
    expect(rendered_content).to include(drafts_notes_path)
    expect(rendered_content).to include(all_notes_path)
  end

  it "renders the all-notes heading and the new-note context" do
    render_inline(described_class.new(list: "all_notes"))

    expect(rendered_content).to include(escaped("note.all_notes"))
    expect(rendered_content).to include("view_context=all_notes")
    expect(rendered_content).to include(drafts_notes_path)
    expect(rendered_content).to include(notes_path)
  end

  it "renders the drafts heading and the new-note context" do
    render_inline(described_class.new(list: "draft_notes"))

    expect(rendered_content).to include(escaped("note.draft_journals"))
    expect(rendered_content).to include("view_context=draft_notes")
    expect(rendered_content).to include(notes_path)
    expect(rendered_content).to include(all_notes_path)
  end

  it "renders the journal title and only the close control" do
    journal = Journal.new(id: 9, title: "Castle")

    render_inline(described_class.new(list: "journal", journal: journal))

    expect(rendered_content).to include(escaped("note.linked_to_journal", title: "Castle"))
    expect(rendered_content).to include(I18n.t("note.close"))
    expect(rendered_content).not_to include("view_context=")
  end

  it "rejects an unknown list" do
    expect { described_class.new(list: "nope") }.to raise_error(ArgumentError, /unknown notes list/)
  end

  it "requires a journal for the journal list" do
    expect { described_class.new(list: "journal") }.to raise_error(ArgumentError, /journal is required/)
  end
end
