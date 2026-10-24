require "rails_helper"

RSpec.describe "source_tag request parameter", type: :request do
  let(:group) { Group.create!(name: "Source tag #{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email_address: "source-tag-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end
  let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html" } }

  before { post session_path, params: { email_address: user.email_address, password: "password" } }

  describe "SourceTag.parse" do
    it "keeps the known tags and drops everything else" do
      expect(SourceTag.parse("ai_assistant")).to eq("ai_assistant")
      expect(SourceTag.parse("notes_box")).to eq("notes_box")
      expect(SourceTag.parse("other")).to be_nil
      expect(SourceTag.parse("")).to be_nil
      expect(SourceTag.parse(nil)).to be_nil
    end
  end

  describe "GET /followups/cancel" do
    it "clears the frame of a known tag" do
      get cancel_followups_path(source_tag: "notes_box"), headers: turbo

      expect(response.body).to include('target="followup_output_notes_box"')
    end

    it "falls back to the AI assistant frame for an unknown tag" do
      get cancel_followups_path(source_tag: %("><img src=x onerror=alert(1)>)), headers: turbo

      expect(response.body).to include('target="followup_output_ai_assistant"')
      expect(response.body).not_to include("onerror")
    end

    it "falls back to the AI assistant frame when the tag is missing" do
      get cancel_followups_path, headers: turbo

      expect(response.body).to include('target="followup_output_ai_assistant"')
    end
  end
end
