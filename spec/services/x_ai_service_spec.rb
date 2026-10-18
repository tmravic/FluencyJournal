require "rails_helper"

RSpec.describe XAiService do
  describe "#call" do
    let(:user) { instance_double(User) }
    let(:journal) { instance_double(Journal) }
    let(:prompt) do
      instance_double(
        EntryPrompt,
        ai_model: "grok-4.7",
        raw_prompt: "raw",
        change_keyword: "change_"
      )
    end
    let(:result) do
      XAiChat::Result.new(
        raw_response: '{"corrected_text":"ok"}',
        parsed: { "corrected_text" => "ok" },
        prompt_tokens: 11,
        completion_tokens: 7,
        total_tokens: 18
      )
    end

    it "sends the role prompt, the entry, and the response format through XAiChat" do
      allow(prompt).to receive(:role_prompt).with(user, journal).and_return("role")
      allow(prompt).to receive(:response_format).with(user, journal, nil).and_return("format")
      service = described_class.new(api_key: "key", prompt: prompt, user: user, journal: journal)
      ai_query = instance_double(AiQuery)
      allow(XAiChat).to receive(:complete).and_return(result)
      allow(service).to receive(:build_ai_query).and_return(ai_query)
      allow(service).to receive(:create_ai_outputs_for_each_change)
      allow(service).to receive(:create_ai_output_for_corrected_text)

      expect(service.call).to eq(ai_query)
      expect(XAiChat).to have_received(:complete).with(
        model: "grok-4.7",
        instructions: "role",
        user_messages: ["raw", "format"]
      )
      expect(service).to have_received(:build_ai_query).with(
        result.raw_response,
        result.token_data,
        prompt,
        journal
      )
    end

    it "does not write a second followup link when the request has an origin" do
      origin = instance_double(Entry)
      allow(prompt).to receive(:role_prompt).with(user, journal).and_return("role")
      allow(prompt).to receive(:response_format).with(user, journal, nil).and_return("format")
      service = described_class.new(
        api_key: "key",
        prompt: prompt,
        user: user,
        journal: journal,
        followup_origin: origin
      )
      ai_query = instance_double(AiQuery)
      allow(XAiChat).to receive(:complete).and_return(result)
      allow(service).to receive(:build_ai_query).and_return(ai_query)
      allow(service).to receive(:create_ai_outputs_for_each_change)
      allow(service).to receive(:create_ai_output_for_corrected_text)

      expect(service.call).to eq(ai_query)
      expect(service).not_to have_received(:create_ai_output_for_corrected_text)
    end

    it "raises the ruby_llm error when xAI rejects the request" do
      response = instance_double(
        Faraday::Response,
        status: 404,
        body: '{"code":"not-found","error":"The model grok-4.6 does not exist or your team does not have access to it."}'
      )
      error = RubyLLM::ForbiddenError.new(response.body, response: response)
      allow(prompt).to receive(:role_prompt).with(user, journal).and_return("role")
      allow(prompt).to receive(:response_format).with(user, journal, nil).and_return("format")
      service = described_class.new(api_key: "key", prompt: prompt, user: user, journal: journal)
      allow(XAiChat).to receive(:complete).and_raise(error)

      expect { service.call }.to raise_error(RubyLLM::ForbiddenError) do |raised|
        expect(raised.response.status).to eq(404)
        expect(raised.response.body).to include("not-found")
      end
    end
  end
end
