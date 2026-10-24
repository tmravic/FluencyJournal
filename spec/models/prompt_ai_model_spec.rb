require "rails_helper"

RSpec.describe Prompt, "ai_model" do
  def build_prompt(model)
    FreeQuestionPrompt.new(raw_prompt: "x", ai_model: model, uuid: SecureRandom.uuid, sent_role_prompt: "r")
  end

  it "defaults to the first allowed model" do
    expect(Prompt::DEFAULT_MODEL).to eq("grok-4-fast-non-reasoning")
    expect(Prompt::MODELS).to eq(%w[grok-4-fast-non-reasoning grok-4.6])
  end

  it "has a label key that resolves in every locale for each model" do
    Prompt::MODEL_LABEL_KEYS.each_value do |key|
      %i[en ja].each { |locale| expect(I18n.exists?(key, locale)).to be(true) }
    end
  end

  it "accepts the allowed models" do
    Prompt::MODELS.each { |model| expect(build_prompt(model)).to be_valid }
  end

  it "rejects an unknown model" do
    prompt = build_prompt("grok-3")

    expect(prompt).not_to be_valid
    expect(prompt.errors[:ai_model]).to be_present
  end

  it "still reports a blank model as blank only" do
    prompt = build_prompt("")

    expect(prompt).not_to be_valid
    expect(prompt.errors.details[:ai_model].map { |e| e[:error] }).to eq([ :blank ])
  end

  it "lets an older row with a retired model be saved when the model is not changed" do
    prompt = build_prompt(Prompt::DEFAULT_MODEL)
    prompt.save!
    prompt.update_column(:ai_model, "grok-3")

    prompt = Prompt.find(prompt.id)
    expect(prompt.update(raw_prompt: "changed")).to be(true)
    expect(prompt.update(ai_model: "grok-3-mini")).to be(false)
  end
end
