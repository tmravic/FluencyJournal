require "rails_helper"

RSpec.describe Prompt, type: :model do
  def learner(original_language: "English", learning_language: "Japanese")
    instance_double(User, original_language: original_language, learning_language: learning_language)
  end

  def journal_for(user)
    instance_double(Journal, full_journal: [ "今日は雨だった。" ], user: user)
  end

  def quiz_double
    instance_double(Quiz, responses: [ "It rained today." ])
  end

  describe "substitutable prompts" do
    let(:subclasses) do
      [
        EntryPrompt,
        ExampleSentencePrompt,
        FreeQuestionPrompt,
        PrepareQuizPrompt,
        QuizResultPrompt
      ]
    end

    it "gives Prompt and every subclass the same two arities" do
      ([ described_class ] + subclasses).each do |prompt_class|
        expect(prompt_class.instance_method(:role_prompt).arity).to eq(2)
        expect(prompt_class.instance_method(:response_format).arity).to eq(3)
      end
    end

    it "raises from the base class when those methods are called with that arity" do
      prompt = described_class.new

      expect { prompt.role_prompt(learner, nil) }.to raise_error(NotImplementedError)
      expect { prompt.response_format(learner, nil, nil) }.to raise_error(NotImplementedError)
    end

    it "answers both methods on every subclass" do
      user = learner
      journal = journal_for(user)
      quiz = quiz_double

      subclasses.each do |prompt_class|
        prompt = prompt_class.new

        expect(prompt.role_prompt(user, journal)).to be_a(String)
        expect(prompt.response_format(user, journal, quiz)).to be_a(String)
      end
    end

    it "declares the item prefix on every subclass and not on the retired base class" do
      expect(subclasses.map { |klass| [ klass.new.change_keyword, klass.new.listable? ] })
        .to eq([ [ "change_", true ], [ "example_", true ], [ "answer_", true ], [ "line_", true ], [ "entry_", true ] ])

      base = described_class.new
      expect(base.listable?).to be false
      expect { base.change_keyword }.to raise_error(NotImplementedError)
    end

    it "lets a note followup omit the journal" do
      text = FreeQuestionPrompt.new.role_prompt(learner, nil)

      expect(text).to include("Followup Question")
      expect(text).not_to include("previous entry")
    end
  end

  describe ".explanation_language_code" do
    it "uses ja for Japanese, the same code text-to-speech sends" do
      user = learner(original_language: "Japanese")

      expect(described_class.explanation_language_code(user)).to eq("ja")
      expect(described_class.language_code("Japanese")).to eq("ja")
      expect(EntryPrompt.new.response_format(user, nil, nil)).to include("explanation_ja")
    end

    it "falls back to en for an unknown language" do
      user = learner(original_language: "Thai")

      expect(described_class.explanation_language_code(user)).to eq("en")
      expect(described_class.language_code("Thai", default: "auto")).to eq("auto")
      expect(EntryPrompt.new.response_format(user, nil, nil)).to include("explanation_en")
    end

    it "is the one language-code map (no copies elsewhere)" do
      expect(AiQuery.new).not_to respond_to(:abbr)
      expect(XAiTtsService.const_defined?(:LANGUAGE_CODES)).to be(false)
    end
  end
end
