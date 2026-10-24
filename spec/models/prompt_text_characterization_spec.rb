require "rails_helper"

# Pins the exact text every Prompt subclass sends to the model, so prompt
# refactors can prove they are byte-for-byte behaviour-preserving.
#
# Snapshots live in spec/fixtures/files/prompt_text_snapshots.json. After an intended
# wording change, regenerate them with:
#   UPDATE_PROMPT_SNAPSHOTS=1 bundle exec rspec spec/models/prompt_text_characterization_spec.rb
RSpec.describe "Prompt text characterization", type: :model do
  users = {
    "ja_learner" => { original_language: "English", learning_language: "Japanese" },
    "en_learner" => { original_language: "Japanese", learning_language: "English" },
    "es_learner" => { original_language: "English", learning_language: "Spanish" }
  }

  def journal
    instance_double(Journal, entry_texts: [ "今日は雨だった。", "傘を忘れた。\n\"困った\"", "two  spaces, 100% sure" ])
  end

  def quiz
    instance_double(Quiz, responses: [ "It rained today.", "I forgot my umbrella." ])
  end

  # One JSON file keeps exact whitespace (including trailing spaces) safe
  # through git and patch tools.
  snapshot_path = Rails.root.join("spec/fixtures/files/prompt_text_snapshots.json")
  snapshots = snapshot_path.exist? ? JSON.parse(snapshot_path.read) : {}
  recorded = {}

  after(:all) do
    if ENV["UPDATE_PROMPT_SNAPSHOTS"]
      FileUtils.mkdir_p(snapshot_path.dirname)
      File.write(snapshot_path, JSON.pretty_generate(snapshots.merge(recorded).sort.to_h) + "\n")
    end
  end

  define_method(:expect_snapshot) do |name, text|
    recorded[name] = text
    next if ENV["UPDATE_PROMPT_SNAPSHOTS"]

    expect(snapshots).to have_key(name), "no snapshot for #{name}; run with UPDATE_PROMPT_SNAPSHOTS=1"
    expect(text).to eq(snapshots[name]), "prompt text changed: #{name}"
  end

  users.each do |label, attrs|
    context "for a #{label}" do
      let(:user) { User.new(**attrs) }

      it "EntryPrompt" do
        prompt = EntryPrompt.new
        expect_snapshot("entry_role_#{label}", prompt.role_prompt(user, journal))
        expect_snapshot("entry_format_#{label}", prompt.response_format(user, journal, nil))
      end

      it "FreeQuestionPrompt with and without a journal" do
        prompt = FreeQuestionPrompt.new
        expect_snapshot("free_question_role_journal_#{label}", prompt.role_prompt(user, journal))
        expect_snapshot("free_question_role_no_journal_#{label}", prompt.role_prompt(user, nil))
        expect_snapshot("free_question_format_#{label}", prompt.response_format(user, nil, nil))
      end

      it "ExampleSentencePrompt" do
        prompt = ExampleSentencePrompt.new
        expect_snapshot("example_sentence_role_#{label}", prompt.role_prompt(user, nil))
        expect_snapshot("example_sentence_format_#{label}", prompt.response_format(user, nil, nil))
      end

      it "QuizResultPrompt" do
        prompt = QuizResultPrompt.new
        expect_snapshot("quiz_result_role_#{label}", prompt.role_prompt(user, journal))
        expect_snapshot("quiz_result_format_#{label}", prompt.response_format(user, journal, quiz))
      end

      it "PrepareQuizPrompt" do
        prompt = PrepareQuizPrompt.new
        expect_snapshot("prepare_quiz_role_#{label}", prompt.role_prompt(user, journal))
        expect_snapshot("prepare_quiz_format_#{label}", prompt.response_format(user, journal, nil))
      end
    end
  end

  it "keeps each prompt's change keyword" do
    expect(
      [ EntryPrompt, FreeQuestionPrompt, ExampleSentencePrompt, QuizResultPrompt, PrepareQuizPrompt ]
        .map { |klass| klass.new.change_keyword }
    ).to eq(%w[change_ answer_ example_ entry_ line_])
  end
end
