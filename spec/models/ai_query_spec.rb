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

    it "returns nil when the model sends an empty change" do
      query = described_class.new(raw_response: '{"change_1":{"content":"","explanation_en":"Direct translation."}}')

      expect(query.change_content("1", "change_")).to be_nil
      expect(query.change_sides("1", "change_")).to be_nil
    end

    it "returns nil for a whitespace change and a missing line" do
      query = described_class.new(
        raw_response: '{"change_1":{"content":"  "},"change_2":{"explanation_en":"No content."}}'
      )

      expect(query.change_content("1", "change_")).to be_nil
      expect(query.change_content("2", "change_")).to be_nil
      expect(query.change_content("9", "change_")).to be_nil
    end

    it "returns both sides without taking the first character of a sentence" do
      arrow = described_class.new(raw_response: '{"change_1":{"content":"小さい針 → マイクロニードル"}}')
      sentence = described_class.new(raw_response: '{"change_1":{"content":"真優の誕生日"}}')

      expect(arrow.change_sides("1", "change_")).to eq([ "小さい針 ", " マイクロニードル" ])
      expect(sentence.change_sides("1", "change_")).to eq([ "真優の誕生日", "真優の誕生日" ])
    end
  end

  describe "#count_changes" do
    it "returns 0 when the body is not an object" do
      query = described_class.new(raw_response: "not json")
      allow(RescueBadFormatJob).to receive(:perform_now).and_return("still bad")

      expect(query.count_changes("change_")).to eq(0)
      expect(query.parsed_response).to be_nil
      query.count_changes("change_")

      expect(RescueBadFormatJob).to have_received(:perform_now).once
    end
  end

  describe "#create_quiz_questions" do
    def quiz_records
      group = Group.create!(name: "Hint group")
      user = User.create!(
        email_address: "hints-#{SecureRandom.hex(4)}@example.com",
        password: "password",
        original_language: "English",
        learning_language: "Japanese",
        group: group
      )
      journal = Journal.create!(title: "Hints", user: user, group: group, last_interval: 1)
      first = journal.entries.create!(content: "一行目")
      second = journal.entries.create!(content: "二行目")
      prompt = PrepareQuizPrompt.create!(
        raw_prompt: "entries",
        sent_role_prompt: "role",
        ai_model: "grok-4-fast-non-reasoning",
        uuid: SecureRandom.uuid
      )
      query = described_class.create!(
        raw_response: "{}",
        prompt: prompt,
        journal: journal,
        prompt_tokens: 1,
        completion_tokens: 1,
        total_tokens: 2
      )
      quiz = Quiz.create!(ai_query: query, journal: journal)
      [query, quiz, first, second]
    end

    it "saves the translation and the hint for each entry" do
      query, quiz, first, second = quiz_records

      query.create_quiz_questions(
        {
          "line_1" => { "translation" => "一行目 → first line", "hint" => "何の一行？" },
          "line_2" => { "translation" => "二行目 → second line", "hint" => { "content" => "何の二行？" } }
        },
        expected_count: 2,
        quiz: quiz
      )

      expect(query.ai_outputs.order(:identifier).map(&:content)).to eq([ "first line", "second line" ])
      expect(quiz.quiz_hints.order(:entry_id).map { |hint| [hint.entry_id, hint.hint_content, hint.ai_query_id] }).to eq([
        [first.id, "何の一行？", query.id],
        [second.id, "何の二行？", query.id]
      ])
    end

    it "stores a placeholder when a line has no hint" do
      query, quiz = quiz_records

      query.create_quiz_questions(
        { "line_1" => "一行目 → first line" },
        expected_count: 2,
        quiz: quiz
      )

      expect(query.ai_outputs.order(:identifier).map(&:content)).to eq([ "first line", "first line" ])
      expect(quiz.quiz_hints.order(:entry_id).map(&:hint_content)).to eq([ "Hint missing", "Hint missing" ])
    end
  end

  describe "#assessment" do
    it "reads the sentence out of whatever object the model nested it in" do
      query = described_class.new(
        raw_response: {
          entry_1: { content: "line" },
          assessment: { summary: "All four answers were left empty." }
        }.to_json
      )

      expect(query.assessment).to eq("All four answers were left empty.")
    end

    it "keeps an assessment that is already a sentence" do
      query = described_class.new(raw_response: '{"assessment":"The answers match."}')

      expect(query.assessment).to eq("The answers match.")
    end

    it "joins every prose field without printing the hash" do
      query = described_class.new(
        raw_response: '{"assessment":{"summary":"One point.","grammar_points":"Watch は."}}'
      )

      expect(query.assessment).to eq("One point.\nWatch は.")
      expect(query.assessment).not_to include("=>")
    end
  end

  describe "#corrected_text" do
    it "reads a corrected sentence stored under an unexpected key" do
      query = described_class.new(raw_response: '{"corrected_text":{"value":"今日は雨だった"}}')

      expect(query.corrected_text).to eq("今日は雨だった")
    end

    it "uses the sentence when the model makes it both the key and the value" do
      sentence = "お時間がかかってしまい申し訳ございません。"
      query = described_class.new(raw_response: { sentence => sentence }.to_json)

      expect(query.corrected_text).to eq(sentence)
    end
  end

  describe "#change_explanation" do
    it "reads an explanation nested under a key other than explanation_en" do
      query = described_class.new(
        raw_response: '{"entry_1":{"content":"line","note":{"comment":"Left blank."}}}'
      )

      expect(query.change_explanation("entry_", "1", "en")).to eq("Left blank.")
    end
  end
end
