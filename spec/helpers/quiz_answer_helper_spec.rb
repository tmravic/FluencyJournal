require "rails_helper"

RSpec.describe QuizAnswerHelper, type: :helper do
  describe "#quiz_answer_match_segments" do
    it "splits matching and mismatching spans for insertions in the user answer" do
      original = "小さい頃からコーヒーとカフェイン入りの飲み物を飲んできました。"
      user_response = "小さい頃からコーヒーとかカフェイン入りの飲み物を飲んできました。"

      expect(helper.quiz_answer_match_segments(original, user_response)).to eq([
        { match: true, text: "小さい頃からコーヒーと" },
        { match: false, text: "か" },
        { match: true, text: "カフェイン入りの飲み物を飲んできました。" }
      ])
    end

    it "marks the full user answer as matching when it equals the original" do
      original = "今日は晴れです。"

      expect(helper.quiz_answer_match_segments(original, original)).to eq([
        { match: true, text: original }
      ])
    end

    it "marks the full user answer as mismatching when the original is blank" do
      user_response = "今日は晴れです。"

      expect(helper.quiz_answer_match_segments("", user_response)).to eq([
        { match: false, text: user_response }
      ])
    end
  end

  describe "#highlighted_quiz_answer" do
    it "wraps only matching spans in the highlight class" do
      original = "小さい頃からコーヒーとカフェイン入りの飲み物を飲んできました。"
      user_response = "小さい頃からコーヒーとかカフェイン入りの飲み物を飲んできました。"

      result = helper.highlighted_quiz_answer(original, user_response)

      expect(result).to include('class="quiz-answer__match">小さい頃からコーヒーと</span>')
      expect(result).to include("<span>か</span>")
      expect(result).to include('class="quiz-answer__match">カフェイン入りの飲み物を飲んできました。</span>')
    end
  end

  describe "#quiz_answer_entry" do
    it "returns the journal entry at the quiz entry identifier index" do
      second_entry = instance_double(Entry)
      ordered_entries = double("ordered_entries")
      journal = instance_double(Journal, entries: ordered_entries)
      quiz_entry = instance_double(AiOutput, identifier: "2")

      allow(ordered_entries).to receive(:order).with(:id).and_return(ordered_entries)
      allow(ordered_entries).to receive(:offset).with(1).and_return(ordered_entries)
      allow(ordered_entries).to receive(:first).and_return(second_entry)

      expect(helper.quiz_answer_entry(journal, quiz_entry)).to eq(second_entry)
    end
  end
end