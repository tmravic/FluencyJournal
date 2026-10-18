require "rails_helper"

RSpec.describe "Owner id params", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user(label)
    group = Group.create!(name: "Owner id #{label} #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "owner-id-#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def create_journal(user, title:)
    Journal.create!(title: title, user: user, group: user.group, last_interval: 1)
  end

  it "returns 303 to the journals index and does not move the journal onto another user" do
    user_a = create_user("a")
    user_b = create_user("b")
    journal = create_journal(user_a, title: "Original")
    sign_in(user_a)

    patch journal_path(journal), params: { journal: { title: "Renamed", user_id: user_b.id } }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journals_path)
    journal.reload
    expect(journal.title).to eq("Renamed")
    expect(journal.user_id).to eq(user_a.id)
  end

  it "returns 303 to the journals index and does not move the note onto another user" do
    user_a = create_user("a")
    user_b = create_user("b")
    note = user_a.notes.create!(content: "Original")
    sign_in(user_a)

    patch note_path(note), params: { note: { content: "Renamed", user_id: user_b.id } }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(journals_path)
    note.reload
    expect(note.content).to eq("Renamed")
    expect(note.user_id).to eq(user_a.id)
  end

  it "links only the journal in the current group" do
    user_a = create_user("a")
    user_b = create_user("b")
    own_journal = create_journal(user_a, title: "Own")
    other_group_journal = create_journal(user_b, title: "Other group")
    note = user_a.notes.create!(content: "Link me")
    sign_in(user_a)

    post update_journals_note_path(note),
         params: { note: { journal_ids: [ own_journal.id, other_group_journal.id ] } }

    expect(response).to be_successful
    expect(response).not_to be_redirect
    expect(note.journals.reload).to contain_exactly(own_journal)
  end

  it "clears journal links when journal_ids is blank" do
    user_a = create_user("a")
    own_journal = create_journal(user_a, title: "Own")
    note = user_a.notes.create!(content: "Linked")
    note.journals << own_journal
    sign_in(user_a)

    post update_journals_note_path(note), params: { note: { journal_ids: [ "" ] } }

    expect(response).to be_successful
    expect(note.journals.reload).to be_empty
  end

  it "clears journal links when journal_ids is an empty list" do
    user_a = create_user("a")
    own_journal = create_journal(user_a, title: "Own")
    note = user_a.notes.create!(content: "Linked")
    note.journals << own_journal
    sign_in(user_a)

    post update_journals_note_path(note), params: { note: { journal_ids: [] } }

    expect(response).to be_successful
    expect(note.journals.reload).to be_empty
  end
end
