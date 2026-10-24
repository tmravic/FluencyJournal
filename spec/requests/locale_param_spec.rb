require "rails_helper"

RSpec.describe "Locale parameter", type: :request do
  it "ignores an unsupported ?locale= value instead of raising" do
    get new_session_path, params: { locale: "xx" }

    expect(response).to have_http_status(:ok)
  end

  it "still honours a supported ?locale= value" do
    get new_session_path, params: { locale: "ja" }

    expect(response).to have_http_status(:ok)
  end
end
