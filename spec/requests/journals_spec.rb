require "rails_helper"

RSpec.describe "/journals", type: :request do
  let(:group) { Group.create!(name: "Journals #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "journals-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let!(:journal) { Journal.create!(title: "My journal", user: user, group: group, last_interval: 1) }

  def sign_in
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  describe "when signed out" do
    it "sends the new journal page to the sign-in page" do
      get new_journal_url

      expect(response).to redirect_to(new_session_path)
    end

    it "does not create a journal" do
      expect { post journals_url, params: { journal: { title: "Sneaky" } } }.not_to change(Journal, :count)

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "when signed in" do
    before { sign_in }

    it "renders the index" do
      get journals_url

      expect(response).to be_successful
    end

    it "renders a journal" do
      get journal_url(journal)

      expect(response).to be_successful
      expect(response.body).to include("My journal")
    end

    it "renders the new journal form" do
      get new_journal_url

      expect(response).to be_successful
      expect(response.body).to include('name="journal[title]"')
    end

    it "renders the edit form" do
      get edit_journal_url(journal)

      expect(response).to be_successful
      expect(response.body).to include('name="journal[title]"')
      expect(response.body).to include("My journal")
    end

    describe "POST /create" do
      it "creates a journal for the user's group and redirects to it" do
        expect {
          post journals_url, params: { journal: { title: "Fresh journal" } }
        }.to change(group.journals, :count).by(1)

        created = group.journals.find_by!(title: "Fresh journal")
        expect(created.user).to eq(user)
        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(journal_url(created))
      end

      it "does not create a journal without a title and re-renders the form with 422" do
        expect {
          post journals_url, params: { journal: { title: "" } }
        }.not_to change(Journal, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('name="journal[title]"')
      end
    end

    describe "PATCH /update" do
      it "updates the title and redirects to the journals list" do
        patch journal_url(journal), params: { journal: { title: "Renamed" } }

        expect(journal.reload.title).to eq("Renamed")
        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(journals_url)
      end

      it "keeps the title and answers 422 when it is blank" do
        patch journal_url(journal), params: { journal: { title: "" } }

        expect(journal.reload.title).to eq("My journal")
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "DELETE /destroy" do
      it "destroys the journal and redirects to the journals list" do
        expect { delete journal_url(journal) }.to change(Journal, :count).by(-1)

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(journals_url)
      end
    end
  end
end
