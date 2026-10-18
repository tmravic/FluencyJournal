require "rails_helper"

RSpec.describe AiQuery, type: :model do
  describe "#parsed_response" do
    it "parses valid JSON" do
      query = described_class.new(raw_response: '{"change_1":{"content":"a → b"}}')

      expect(query.parsed_response).to eq("change_1" => { "content" => "a → b" })
    end

    it "parses JSON wrapped in a markdown fence" do
      query = described_class.new(raw_response: "```json\n{\"corrected_text\":\"今日は雨だった\"}\n```")

      expect(query.parsed_response).to eq("corrected_text" => "今日は雨だった")
    end

    it "flattens an answers object into answer_N keys" do
      query = described_class.new(
        raw_response: '{"answers":{"1":{"content":"例文"},"2":{"content":"別の例文"}}}'
      )

      expect(query.parsed_response).to eq(
        "answer_1" => { "content" => "例文" },
        "answer_2" => { "content" => "別の例文" }
      )
    end

    it "asks RescueBadFormatJob to repair invalid JSON" do
      query = described_class.new(raw_response: "{change_1: not json")
      allow(RescueBadFormatJob).to receive(:perform_now).with(query).and_return('{"ok":true}')

      expect(query.parsed_response).to eq("ok" => true)
      expect(RescueBadFormatJob).to have_received(:perform_now).with(query)
    end

    it "does not call RescueBadFormatJob for valid JSON" do
      query = described_class.new(raw_response: '{"corrected_text":"ok"}')
      allow(RescueBadFormatJob).to receive(:perform_now)

      query.parsed_response

      expect(RescueBadFormatJob).not_to have_received(:perform_now)
    end
  end

  describe "#change_content" do
    it "splits on the arrow the grade prompt requests" do
      query = described_class.new(raw_response: '{"entry_1":{"content":"Test → 本当の文"}}')

      expect(query.change_content("1", "entry_")).to eq([ "Test ", " 本当の文" ])
    end

    it "splits when the model uses the down arrow the card draws" do
      query = described_class.new(raw_response: '{"entry_1":{"content":"Test ↓ 本当の文"}}')

      expect(query.change_content("1", "entry_")).to eq([ "Test ", " 本当の文" ])
    end

    it "splits an ASCII arrow" do
      query = described_class.new(raw_response: '{"entry_1":{"content":"Test -> 本当の文"}}')

      expect(query.change_content("1", "entry_")).to eq([ "Test ", " 本当の文" ])
    end

    it "keeps a sentence that has no arrow as one string" do
      query = described_class.new(raw_response: '{"entry_1":{"content":"真優の誕生日"}}')

      expect(query.change_content("1", "entry_")).to eq("真優の誕生日")
    end
  end

end
