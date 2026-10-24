require "rails_helper"

RSpec.describe "Login", type: :system do

  def create_user(email:, password:)
    group = Group.create!(name: "Login spec #{SecureRandom.hex(4)}")
    User.create!(
      email_address: email,
      password: password,
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  it "signs in with valid credentials and shows the homepage for the user" do
    user = create_user(email: "login-ok@example.com", password: "password")

    visit new_session_path

    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Sign in"

    expect(page).to have_current_path(root_path)
    expect(page).to have_content(user.name)
    expect(page).to have_button("Logout")
    expect(page).to have_link("View journals")
  end

  it "rejects invalid credentials and stays on the sign-in page" do
    user = create_user(email: "login-bad@example.com", password: "password")

    visit new_session_path

    fill_in "email_address", with: user.email_address
    fill_in "password", with: "wrong-password"
    click_button "Sign in"

    expect(page).to have_current_path(new_session_path)
    expect(page).to have_content("Try another email address or password.")
    expect(page).to have_button("Sign in")
  end
end
