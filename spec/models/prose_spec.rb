require "rails_helper"

RSpec.describe Prose do
  describe ".from" do
    it "strips strings and drops blank ones" do
      expect(described_class.from("  雨 ")).to eq("雨")
      expect(described_class.from("   ")).to be_nil
    end

    it "joins array items with newlines and drops repeats" do
      expect(described_class.from([ "a", [ "b", "c" ], "a", nil, 3 ])).to eq("a\nb\nc")
    end

    it "reads the values of an object" do
      expect(described_class.from("text" => "一", "note" => [ "二" ])).to eq("一\n二")
    end

    it "falls back to a sentence-like key when its value has no text" do
      expect(described_class.from("今日は雨。" => nil, "word" => nil)).to eq("今日は雨。")
    end

    it "has no text for numbers, booleans and nil" do
      expect([ 1, true, nil ].map { |value| described_class.from(value) }).to eq([ nil, nil, nil ])
    end
  end

  describe ".sentence_key?" do
    it "accepts keys with kana, kanji or a space" do
      expect([ "雨", "ひらがな", "カタカナ", "two words" ].map { |key| described_class.sentence_key?(key) }).to all(be(true))
    end

    it "rejects identifiers, blanks and non-strings" do
      expect([ "text", "line_1", " ", "", :sym, nil ].map { |key| described_class.sentence_key?(key) }).to all(be(false))
    end
  end
end
