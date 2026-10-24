require "rails_helper"

RSpec.describe AiQuery, type: :model do
  describe ".from_chat" do
    let(:prompt) { Prompt.create!(raw_prompt: "x", ai_model: "m", uuid: SecureRandom.uuid, sent_role_prompt: "r") }
    let(:token_data) { { "prompt_tokens" => 3, "completion_tokens" => 4, "total_tokens" => 7 } }

    it "builds an unsaved query with the reply, token counts and prompt" do
      query = described_class.from_chat(raw_response: "{}", token_data: token_data, prompt: prompt)

      expect(query).to be_new_record
      expect(query.attributes.values_at("raw_response", "prompt_tokens", "completion_tokens", "total_tokens"))
        .to eq([ "{}", 3, 4, 7 ])
      expect(query.prompt).to eq(prompt)
      expect(query.journal).to be_nil
      expect(query.change_count).to be_nil
    end

    it "sets the journal when there is one" do
      group = Group.create!(name: "From chat #{SecureRandom.hex(4)}")
      user = User.create!(email_address: "from-chat-#{SecureRandom.hex(4)}@example.com", password: "password",
                          original_language: "English", learning_language: "Japanese", group: group)
      journal = Journal.create!(title: "J", user: user, group: group, last_interval: 1)

      query = described_class.from_chat(raw_response: "{}", token_data: token_data, prompt: prompt, journal: journal)

      expect(query.journal).to eq(journal)
    end
  end

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

    it "returns nil for invalid JSON without calling the model" do
      query = described_class.new(raw_response: "{change_1: not json")
      allow(XAiChat).to receive(:complete)

      expect(query.parsed_response).to be_nil
      expect(query.parsed_response).to be_nil
      expect(XAiChat).not_to have_received(:complete)
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

  describe "#error_message" do
    it "is localized" do
      query = described_class.new(raw_response: "{}")

      expect(query.error_message).to eq("something went wrong")
      expect(I18n.with_locale(:ja) { query.error_message }).to eq("問題が発生しました。")
    end
  end

  describe "#parsed_response memo" do
    it "re-parses after raw_response is reassigned" do
      query = described_class.new(raw_response: { "change_1" => { "content" => "a" } }.to_json)
      expect(query.parsed_response.keys).to eq([ "change_1" ])

      query.raw_response = { "line_1" => "b" }.to_json

      expect(query.parsed_response).to eq("line_1" => "b")
    end
  end

  describe "#count_changes" do
    it "returns 0 when the body is not an object" do
      query = described_class.new(raw_response: "not json")
      allow(XAiChat).to receive(:complete)

      expect(query.count_changes("change_")).to eq(0)
      expect(query.parsed_response).to be_nil
      expect(query.count_changes("change_")).to eq(0)
      expect(XAiChat).not_to have_received(:complete)
    end

    it "counts only keys that start with the numbered prefix" do
      body = {
        "change_1" => { "content" => "a → b" },
        "change_2" => { "content" => "c → d" },
        "exchange_1" => { "content" => "not a change" },
        "corrected_text" => { "text" => "b d" }
      }.to_json

      expect(described_class.new(raw_response: body).count_changes("change_")).to eq(2)
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

    it "orders lines numerically, keeps text after the last arrow, and ignores other keys" do
      query, = quiz_records

      query.create_quiz_questions(
        {
          "line_10" => { "translation" => "ten" },
          "line_2" => { "translation" => "二 → two → deux" },
          "line_1" => "one",
          "note" => "ignored"
        },
        expected_count: 3
      )

      expect(query.ai_outputs.order(:identifier).map { |o| [ o.identifier, o.role, o.content ] }).to eq(
        [ [ "1", "line", "one" ], [ "2", "line", "deux" ], [ "3", "line", "ten" ] ]
      )
    end

    it "uses the placeholder text when no line came back and logs the mismatch" do
      query, quiz = quiz_records
      allow(Rails.logger).to receive(:warn)

      query.create_quiz_questions({}, expected_count: 1, quiz: quiz)

      expect(query.ai_outputs.map(&:content)).to eq([ "Translation missing" ])
      expect(Rails.logger).to have_received(:warn).with(/line-count mismatch.*expected=1 actual=0/)
    end

    it "creates one question per returned line when no count is given and skips hints without a quiz" do
      query, = quiz_records

      query.create_quiz_questions({ "line_1" => "a", "line_2" => "b" })

      expect(query.ai_outputs.order(:identifier).map(&:content)).to eq(%w[a b])
      expect(QuizHint.count).to eq(0)
    end

    it "raises when a returned line has no translation text" do
      query, = quiz_records

      expect { query.create_quiz_questions({ "line_1" => { "hint" => "h" } }, expected_count: 1) }
        .to raise_error(ActiveRecord::RecordInvalid)
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

    it "reads a stored explanation_jp when the language code is ja" do
      query = described_class.new(
        raw_response: '{"change_1":{"content":"a → b","explanation_jp":"古い説明"}}'
      )

      expect(query.change_explanation("change_", "1", "ja")).to eq("古い説明")
    end

    it "prefers explanation_ja over a stored explanation_jp" do
      query = described_class.new(
        raw_response: '{"change_1":{"explanation_ja":"新しい説明","explanation_jp":"古い説明"}}'
      )

      expect(query.change_explanation("change_", "1", "ja")).to eq("新しい説明")
    end
  end

  describe "example sentence items" do
    it "are not treated as prose by corrected_text or assessment" do
      body = {
        "example_1" => {
          "content" => {
            "reading" => "(かく.ご) 覚悟",
            "English_example_sentence" => "I am ready.",
            "Japanese_example_sentence" => "覚悟はできている。"
          }
        }
      }.to_json
      query = described_class.new(raw_response: body)

      expect(query.corrected_text).to be_nil
      expect(query.assessment).to be_nil
    end
  end
end
