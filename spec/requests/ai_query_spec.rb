require 'rails_helper'

RSpec.describe "AiQueries", type: :request do
  describe "GET /show" do
    it "returns http success" do
      get "/ai_queries/show"
      expect(response).to have_http_status(:success)
    end
  end

end
