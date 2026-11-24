require "rails_helper"

# PublicExceptions picks public/404.<locale>.html from I18n.locale. The
# controller restores the locale before ShowExceptions runs, so the locale has
# to be set by middleware outside that rescue. Tests show the debug page unless
# detailed exceptions are turned off.
RSpec.describe "Public error pages", type: :request do
  around do |example|
    env_config = Rails.application.env_config
    original = env_config["action_dispatch.show_detailed_exceptions"]
    env_config["action_dispatch.show_detailed_exceptions"] = false
    example.run
  ensure
    env_config["action_dispatch.show_detailed_exceptions"] = original
  end

  def miss(headers)
    get "/no-such-page-#{SecureRandom.hex(4)}", headers: headers.merge("Accept" => "text/html")
  end

  it "renders the Japanese 404 when the browser asks for Japanese" do
    miss("Accept-Language" => "ja")

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("お探しのページは見つかりません。")
    expect(response.body).not_to include("The page you were looking for")
  end

  it "renders the English 404 when the browser asks for English" do
    miss("Accept-Language" => "en-US,ja")

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("The page you were looking for")
    expect(response.body).not_to include("お探しのページは見つかりません。")
  end

  it "lets ?locale= win over Accept-Language" do
    get "/no-such-page-#{SecureRandom.hex(4)}",
        params: { locale: "ja" },
        headers: { "Accept" => "text/html", "Accept-Language" => "en" }

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("お探しのページは見つかりません。")
  end

  it "falls back to the English page when no locale is requested" do
    miss({})

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("The page you were looking for")
  end
end
