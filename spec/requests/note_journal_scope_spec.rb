require "rails_helper"

# Notes only list, look up and link the user's own journals. Groups share
# journals for viewing, not for linking notes.
RSpec.describe "Note journal scope", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user(group, label)
    User.create!(
      email_address: "note-scope-#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  let(:group) { Group.create!(name: "Note scope #{SecureRandom.hex(4)}") }
  let(:user) { create_user(group, "me") }
  let(:mate) { create_user(group, "mate") }
  let!(:own_journal) { Journal.create!(title: "My journal", user: user, group: group, last_interval: 1) }
  let!(:mate_journal) { Journal.create!(title: "Mate journal", user: mate, group: group, last_interval: 1) }
  let(:note) { user.notes.create!(content: "Link me") }

  it "lists only the user's own journals in the link picker" do
    sign_in(user)

    get link_journals_note_path(note)

    expect(response).to be_successful
    expect(response.body).to include("My journal")
    expect(response.body).not_to include("Mate journal")
  end

  it "links the user's own journal" do
    sign_in(user)

    post update_journals_note_path(note), params: { note: { journal_ids: [ own_journal.id ] } }

    expect(response).to be_successful
    expect(note.journals.reload).to contain_exactly(own_journal)
  end

  it "does not link a group-mate's journal" do
    sign_in(user)

    post update_journals_note_path(note), params: { note: { journal_ids: [ own_journal.id, mate_journal.id ] } }
    expect(note.journals.reload).to contain_exactly(own_journal)

    post update_journals_note_path(note), params: { note: { journal_ids: [ mate_journal.id ] } }
    expect(note.journals.reload).to be_empty
  end

  it "shows notes for the user's own journal and 404s for a group-mate's" do
    sign_in(user)

    get for_journal_notes_path(journal_id: own_journal.id)
    expect(response).to be_successful

    get for_journal_notes_path(journal_id: mate_journal.id)
    expect(response).to have_http_status(:not_found)
  end

  it "still 404s for a journal in another group" do
    other_group = Group.create!(name: "Other #{SecureRandom.hex(4)}")
    outsider = create_user(other_group, "outsider")
    foreign = Journal.create!(title: "Foreign", user: outsider, group: other_group, last_interval: 1)
    sign_in(user)

    get for_journal_notes_path(journal_id: foreign.id)

    expect(response).to have_http_status(:not_found)
  end
end
