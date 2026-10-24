require "rails_helper"

# Pins how AiQuery turns the model's JSON into prose and change lines, for
# every response shape the specs have met, before that logic is moved out of
# the model (M10) and the positional fallback is shared (M9). The values are
# what the code returned when the spec was written, odd ones included.
RSpec.describe AiQuery, "response text (characterization)" do
  def query(raw)
    described_class.new(raw_response: raw.is_a?(String) ? raw : raw.to_json)
  end

  describe "prose extraction (corrected_text / assessment)" do
    {
      "a bare string" => [ "今日は雨だった。", nil, nil ],
      "an array, de-duplicated and flattened" => [ [ "a b", [ "雨", { "x" => "傘 を" } ], "a b" ], "a b\n雨\n傘 を", "a b\n雨\n傘 を" ],
      "a wrapper with a text field and a repeated note" =>
        [ { "corrected_text" => { "text" => " 今日。 ", "note" => [ "x", "今日。" ] } }, "今日。\nx\n今日。", "今日。\nx\n今日。" ],
      "a kana sentence used as a key with an empty value" =>
        [ { "corrected_text" => { "今日は雨だった。" => "" } }, "今日は雨だった。", "今日は雨だった。" ],
      "a key with a space and a nil value" => [ { "corrected_text" => { "hello world" => nil } }, "hello world", "hello world" ],
      "a single-word key and a nil value" => [ { "corrected_text" => { "word" => nil } }, nil, nil ],
      "a number value" => [ { "corrected_text" => { "a" => 1 } }, nil, nil ],
      "a sentence that is both key and value" => [ { "今日は雨。" => "今日は雨。", "x" => "y" }, "今日は雨。", "今日は雨。\ny" ],
      "numbered items next to a leftover field" =>
        [ { "change_1" => { "content" => "a → b" }, "hint_1" => "h", "text" => "残り" }, "残り", "残り" ],
      "the corrected_japanese key" => [ { "corrected_japanese" => "文。" }, "文。", "文。" ],
      "an empty object" => [ {}, nil, nil ]
    }.each do |name, (raw, corrected, assessment)|
      it "reads #{name}" do
        expect(query(raw).corrected_text).to eq(corrected)
        expect(query(raw).assessment).to eq(assessment)
      end
    end
  end

  describe "positional fallback for change lines" do
    let(:positional) do
      query(
        "corrected_text" => { "text" => "x" },
        "a" => { "content" => "A → B", "explanation_en" => "E1" },
        "b" => { "content" => [ "c", "d" ], "explanation_ja" => "J" }
      )
    end

    it "takes the Nth key's content when the numbered key is missing" do
      expect(positional.change_content(1, "change_")).to be_nil
      expect(positional.change_content(2, "change_")).to eq("A → B")
      expect(positional.change_content("2", "change_")).to eq("A → B")
      expect(positional.change_content(3, "change_")).to eq("c\nd")
      expect(positional.change_content(4, "change_")).to be_nil
    end

    it "answers the error message when no explanation matches the Nth key" do
      error = positional.error_message

      [ [ 1, "en" ], [ 2, "ja" ], [ 3, "en" ], [ 4, "en" ] ].each do |num, abbr|
        expect(positional.change_explanation("change_", num, abbr)).to eq(error)
      end
    end

    it "reads the Nth key's explanation for the language code" do
      query = query("a" => { "content" => "c", "explanation_en" => "E1" }, "b" => { "content" => "d", "explanation_ja" => "J", "explanation_jp" => "旧" })

      expect(query.change_explanation("change_", 1, "en")).to eq("E1")
      expect(query.change_explanation("change_", 2, "ja")).to eq("J")
      expect(query.change_explanation("change_", 2, "en")).to eq(query.error_message)
    end

    it "raises TypeError when the Nth key holds a plain string (existing bug)" do
      string_first = query("corrected_text" => "x", "k" => "v")

      expect { string_first.change_content(2, "change_") }.to raise_error(TypeError)
      expect { string_first.change_explanation("change_", 2, "en") }.to raise_error(TypeError)
    end
  end

  describe "explanations stored under the numbered key" do
    let(:numbered) do
      query(
        "change_1" => { "content" => "a", "explanation_jp" => "旧" },
        "change_2" => "plain explanation",
        "change_3" => { "content" => "c", "reason" => "because" }
      )
    end

    it "reads the legacy and fuzzy fields" do
      expect(numbered.change_explanation("change_", 1, "ja")).to eq("旧")
      expect(numbered.change_explanation("change_", 1, "en")).to eq("旧")
      expect(numbered.change_explanation("change_", 3, "en")).to eq("because")
    end

    it "raises TypeError for a bare string item (existing bug)" do
      expect { numbered.change_explanation("change_", 2, "en") }.to raise_error(TypeError)
    end

    it "gives the error message / nil when the body is not an object" do
      expect(query("not json").change_explanation("change_", 1, "en")).to eq(query("not json").error_message)
      expect(query("[1]").change_content(1, "change_")).to be_nil
    end
  end
end
