require 'rails_helper'

RSpec.describe "FollowupTemplatePrompts", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/followup_template_prompts/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/followup_template_prompts/destroy"
      expect(response).to have_http_status(:success)
    end
  end

end
