require "rails_helper"

RSpec.describe RescueBadFormatJob, type: :job do
  it "stores the JSON ruby_llm parsed" do
    query = instance_double(AiQuery, id: 1, raw_response: "{bad")
    result = XAiChat::Result.new(
      raw_response: '{"ok":true}',
      parsed: { "ok" => true },
      prompt_tokens: 3,
      completion_tokens: 4,
      total_tokens: 7
    )
    allow(XAiChat).to receive(:complete).and_return(result)
    allow(query).to receive(:update)

    expect(described_class.perform_now(query)).to eq('{"ok":true}')
    expect(XAiChat).to have_received(:complete).with(
      model: "grok-4-1-fast-non-reasoning",
      instructions: "You are a JSON formatting assistant. Output only valid JSON, no extra text.",
      user_messages: ["Fix this invalid string to valid JSON:\n{bad"]
    )
    expect(query).to have_received(:update).with(raw_response: '{"ok":true}')
  end
end
