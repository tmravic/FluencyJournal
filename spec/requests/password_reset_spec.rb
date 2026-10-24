require "rails_helper"

RSpec.describe "Password reset", type: :request do
  def create_user
    group = Group.create!(name: "Password reset #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "reset-#{SecureRandom.hex(4)}@example.com",
      password: "old-password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  describe "PUT /passwords/:token" do
    it "signs the user out of every existing session" do
      user = create_user
      user.sessions.create!(user_agent: "phone", ip_address: "127.0.0.1")
      user.sessions.create!(user_agent: "laptop", ip_address: "127.0.0.1")

      put password_path(user.password_reset_token),
          params: { password: "new-password", password_confirmation: "new-password" }

      expect(response).to redirect_to(new_session_path)
      expect(user.sessions.count).to eq(0)
      expect(user.reload.authenticate("new-password")).to be_truthy
    end

    it "keeps the sessions when the new password is rejected" do
      user = create_user
      user.sessions.create!(user_agent: "phone", ip_address: "127.0.0.1")

      put password_path(user.password_reset_token),
          params: { password: "new-password", password_confirmation: "different" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.sessions.count).to eq(1)
    end
  end

  describe "rate limiting" do
    # The test cache is a null store, which never counts. Give the store the
    # controller captured a real counter so the limit can fire.
    before do
      counts = Hash.new(0)
      allow(ActionController::Base.cache_store).to receive(:increment) do |key, amount = 1, **|
        counts[key] += amount
      end
    end

    it "redirects with an alert after 10 reset requests in the window" do
      10.times do
        post passwords_path, params: { email_address: "nobody@example.com" }
        expect(flash[:notice]).to eq(I18n.t("password.reset_sent"))
      end

      post passwords_path, params: { email_address: "nobody@example.com" }

      expect(response).to redirect_to(new_password_url)
      expect(flash[:alert]).to eq(I18n.t("session.try_again_later"))
    end

    it "queues no email once the limit is hit" do
      user = create_user
      11.times { post passwords_path, params: { email_address: user.email_address } }

      expect(ActionMailer::MailDeliveryJob).to have_been_enqueued.exactly(10).times
    end
  end
end
