require "rails_helper"

RSpec.describe "DELETE followup template prompts", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def create_user(label)
    group = Group.create!(name: "Templates #{label} #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "templates-#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  it "lists this user's template ids" do
    user = create_user("owner")
    other = create_user("other")
    mine = FollowupTemplatePrompt.create!(base_content: "Same words", user: user)
    theirs = FollowupTemplatePrompt.create!(base_content: "Same words", user: other)
    sign_in(user)

    get followup_template_prompts_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(<option value="#{mine.id}">Same words</option>))
    expect(response.body).not_to include(%(value="#{theirs.id}"))
  end

  it "deletes the selected template and leaves another user's copy" do
    user = create_user("owner")
    other = create_user("other")
    mine = FollowupTemplatePrompt.create!(base_content: "Same words", user: user)
    theirs = FollowupTemplatePrompt.create!(base_content: "Same words", user: other)
    sign_in(user)

    delete destroy_selected_followup_template_prompts_path,
           params: { prompt_template: mine.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Same words")
    expect(flash[:notice]).to eq(I18n.t("prompt_templates.deleted"))
    expect(FollowupTemplatePrompt.exists?(mine.id)).to be(false)
    expect(FollowupTemplatePrompt.exists?(theirs.id)).to be(true)
  end

  it "does not delete another user's template when that id is submitted" do
    user = create_user("owner")
    other = create_user("other")
    theirs = FollowupTemplatePrompt.create!(base_content: "Same words", user: other)
    sign_in(user)

    delete destroy_selected_followup_template_prompts_path,
           params: { prompt_template: theirs.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(flash[:alert]).to eq(I18n.t("prompt_templates.no_selection"))
    expect(FollowupTemplatePrompt.exists?(theirs.id)).to be(true)
  end

  it "redirects a non-Turbo delete back to the template list" do
    user = create_user("owner")
    mine = FollowupTemplatePrompt.create!(base_content: "Mine only", user: user)
    sign_in(user)

    delete destroy_selected_followup_template_prompts_path, params: { prompt_template: mine.id }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(followup_template_prompts_path)
    expect(FollowupTemplatePrompt.exists?(mine.id)).to be(false)
  end
end
