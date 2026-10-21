require "rails_helper"

# Pins the three text-to-speech endpoints before C1 moves them into one
# concern. XAiTtsService is stubbed; no audio request leaves the test.
RSpec.describe "Speak endpoints (characterization)", type: :request do
  let(:group) { Group.create!(name: "Speak #{SecureRandom.hex(4)}") }

  def make_user(learning)
    User.create!(email_address: "speak-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: learning, group: group)
  end

  def records_for(user)
    journal = Journal.create!(title: "Spoken", user: user, group: group, last_interval: 1)
    entry = journal.entries.create!(content: "一行目")
    journal.entries.create!(content: "二行目")
    prompt = EntryPrompt.create!(raw_prompt: "x", ai_model: "m", uuid: SecureRandom.uuid, sent_role_prompt: "r")
    query = AiQuery.create!(journal: journal, prompt: prompt, raw_response: "{}")
    output = query.ai_outputs.create!(identifier: "1", content: "出力の文", made_note: false)
    { journal: journal, entry: entry, output: output }
  end

  def paths(records)
    {
      "journal" => [ speak_journal_path(records[:journal]), "一行目\n\n二行目" ],
      "entry" => [ speak_journal_entry_path(records[:journal], records[:entry]), "一行目" ],
      "ai_output" => [ speak_ai_output_path(records[:output]), "出力の文" ]
    }
  end

  { "Japanese" => "ja", "Spanish" => "auto" }.each do |learning, language|
    context "for a #{learning} learner" do
      let(:user) { make_user(learning) }
      let(:records) { records_for(user) }

      before { post session_path, params: { email_address: user.email_address, password: "password" } }

      %w[journal entry ai_output].each do |name|
        it "streams #{name} audio with language #{language}" do
          service = instance_double(XAiTtsService, call: "MP3-BYTES")
          allow(XAiTtsService).to receive(:new).and_return(service)
          path, text = paths(records).fetch(name)

          get path

          expect(XAiTtsService).to have_received(:new).with(
            api_key: Rails.application.credentials.xai[:api_key], text: text, language: language
          )
          expect(response).to have_http_status(:ok)
          expect(response.media_type).to eq("audio/mpeg")
          expect(response.headers["Content-Disposition"]).to eq("inline")
          expect(response.body).to eq("MP3-BYTES")
        end

        it "answers 503 with an empty body when #{name} speech fails" do
          service = instance_double(XAiTtsService)
          allow(service).to receive(:call).and_raise(XAiTtsService::TtsError, "boom")
          allow(XAiTtsService).to receive(:new).and_return(service)

          get paths(records).fetch(name).first

          expect(response).to have_http_status(:service_unavailable)
          expect(response.body).to be_empty
        end
      end
    end
  end
end
