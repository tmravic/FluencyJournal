require "rails_helper"

# Entries only exist inside a journal, so every route is nested under it.
RSpec.describe "/journals/:journal_id/entries", type: :request do
  let(:group) { Group.create!(name: "Entries #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "entries-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:journal) { Journal.create!(title: "Entries journal", user: user, group: group, last_interval: 1) }
  let!(:entry) { journal.entries.create!(content: "最初の行です。") }

  before { post session_path, params: { email_address: user.email_address, password: "password" } }

  describe "GET /new" do
    it "renders the new entry form" do
      get new_journal_entry_path(journal)

      expect(response).to be_successful
      expect(response.body).to include('name="entry[content]"')
    end
  end

  describe "GET /edit" do
    it "renders the edit form with the entry's text" do
      get edit_journal_entry_path(journal, entry)

      expect(response).to be_successful
      expect(response.body).to include("最初の行です。")
    end
  end

  describe "POST /create" do
    it "adds the entry to the journal and redirects to it" do
      expect {
        post journal_entries_path(journal), params: { entry: { content: "二行目です。" } }
      }.to change(journal.entries, :count).by(1)

      expect(journal.entries.ordered.last.content).to eq("二行目です。")
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(journal_path(journal))
    end

    it "does not add a blank entry and re-renders the form with 422" do
      expect {
        post journal_entries_path(journal), params: { entry: { content: "" } }
      }.not_to change(Entry, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('name="entry[content]"')
    end
  end

  describe "PATCH /update" do
    it "changes the content and redirects to the journal" do
      patch journal_entry_path(journal, entry), params: { entry: { content: "直した行です。" } }

      expect(entry.reload.content).to eq("直した行です。")
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(journal_path(journal))
    end

    it "keeps the content and answers 422 when it is blank" do
      patch journal_entry_path(journal, entry), params: { entry: { content: "" } }

      expect(entry.reload.content).to eq("最初の行です。")
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /destroy" do
    it "removes the entry and redirects to the journal" do
      expect { delete journal_entry_path(journal, entry) }.to change(Entry, :count).by(-1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(journal_path(journal))
    end
  end
end
