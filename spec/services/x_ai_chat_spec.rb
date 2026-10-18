require "rails_helper"

RSpec.describe XAiChat do
  describe ".build" do
    it "asks chat completions for JSON and keeps the stored model id" do
      chat = described_class.build(
        model: "grok-4-fast-non-reasoning",
        instructions: "Be a tutor",
        user_messages: ["raw", "format"]
      )
      payload = chat.render

      expect(payload[:model]).to eq("grok-4-fast-non-reasoning")
      expect(payload[:response_format]).to eq({ type: "json_object" })
      expect(payload[:messages].map { |message| [message[:role], message[:content]] }).to eq([
        ["system", "Be a tutor"],
        ["user", "raw"],
        ["user", "format"]
      ])
    end

    it "keeps grok-4-1-fast-non-reasoning on the payload" do
      chat = described_class.build(
        model: "grok-4-1-fast-non-reasoning",
        instructions: "Fix JSON",
        user_messages: ["{bad"]
      )

      expect(chat.render[:model]).to eq("grok-4-1-fast-non-reasoning")
    end
  end

  describe ".complete" do
    it "stores parsed JSON and maps token counts" do
      message = RubyLLM::Message.new(
        role: :assistant,
        content: "{\n  \"ok\": true\n}",
        input_tokens: 11,
        output_tokens: 7
      )
      chat = instance_double(RubyLLM::Chat, complete: message)
      allow(described_class).to receive(:build).and_return(chat)

      result = described_class.complete(model: "grok-4.7", instructions: "role", user_messages: ["raw"])

      expect(result.parsed).to eq("ok" => true)
      expect(result.raw_response).to eq('{"ok":true}')
      expect(result.prompt_tokens).to eq(11)
      expect(result.completion_tokens).to eq(7)
      expect(result.total_tokens).to eq(18)
      expect(result.token_data).to eq(
        "prompt_tokens" => 11,
        "completion_tokens" => 7,
        "total_tokens" => 18
      )
    end

    it "keeps an unparseable body and does not invent token counts" do
      message = RubyLLM::Message.new(role: :assistant, content: "not json")
      chat = instance_double(RubyLLM::Chat, complete: message)
      allow(described_class).to receive(:build).and_return(chat)

      result = described_class.complete(model: "grok-4.7", instructions: "role", user_messages: ["raw"])

      expect(result.parsed).to be_nil
      expect(result.raw_response).to eq("not json")
      expect { result.parsed_object }.to raise_error(JSON::ParserError)
      expect(result.prompt_tokens).to be_nil
      expect(result.completion_tokens).to be_nil
      expect(result.total_tokens).to be_nil
    end
  end
end
