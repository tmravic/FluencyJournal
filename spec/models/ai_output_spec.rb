require "rails_helper"

RSpec.describe AiOutput, type: :model do
  def assistant_records(raw_response)
    group = Group.create!(name: "Blank change group")
    user = User.create!(
      email_address: "blank-change-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Blank change", user: user, group: group, last_interval: 1)
    prompt = EntryPrompt.create!(
      raw_prompt: "Original Language: The story of Harry Potter still works if Malfoy were a girl.",
      sent_role_prompt: "role",
      base_content: "The story of Harry Potter still works if Malfoy were a girl.",
      user_generated_content: "Japanese",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid
    )
    query = AiQuery.create!(
      raw_response: raw_response,
      change_count: query_change_count(raw_response, prompt),
      prompt: prompt,
      journal: journal,
      prompt_tokens: 647,
      completion_tokens: 61,
      total_tokens: 708
    )
    [ user, prompt, query ]
  end

  def query_change_count(raw_response, prompt)
    AiQuery.new(raw_response: raw_response).count_changes(prompt.change_keyword)
  end

  let(:blank_change_body) do
    {
      "change_1" => {
        "content" => "",
        "explanation_en" => "Original English entry translated directly into natural Japanese diary style."
      },
      "corrected_text" => "ハリーポッターの話は、マルフォイが女の子でも成立すると思う"
    }.to_json
  end

  describe "a blank change line" do
    it "skips the empty change and still stores the corrected sentence" do
      user, prompt, query = assistant_records(blank_change_body)
      service = XAiService.new

      expect {
        service.create_ai_outputs_for_each_change(query, prompt, user)
        service.create_ai_output_for_corrected_text(query, prompt, user)
      }.not_to raise_error

      identifiers = query.ai_outputs.pluck(:identifier)
      expect(identifiers).to eq([ "corrected_text" ])
      expect(query.ai_outputs.first.content).to include("ハリーポッターの話は、マルフォイが女の子でも成立すると思う")
    end

    it "does not call first on the missing sides" do
      user, _prompt, query = assistant_records(blank_change_body)
      output = query.ai_outputs.build(made_note: false, identifier: "1")

      expect(output.assemble_content("change_", user)).to be_nil
    end
  end

  describe "related empty bodies" do
    it "skips a whitespace change and a missing content key" do
      user, prompt, query = assistant_records(
        {
          "change_1" => { "content" => "   ", "explanation_en" => "Spaces." },
          "change_2" => { "explanation_en" => "No content key." },
          "corrected_text" => "文"
        }.to_json
      )
      service = XAiService.new
      service.create_ai_outputs_for_each_change(query, prompt, user)
      service.create_ai_output_for_corrected_text(query, prompt, user)

      expect(query.ai_outputs.pluck(:identifier)).to eq([ "corrected_text" ])
    end

    it "skips a change whose content has no text and still saves a real change" do
      user, prompt, query = assistant_records(
        {
          "change_1" => { "content" => { "note" => "" }, "explanation_en" => "Empty hash." },
          "change_2" => { "content" => "小さい針 → マイクロニードル", "explanation_en" => "Use the usual word." },
          "corrected_text" => "直した文"
        }.to_json
      )
      service = XAiService.new
      service.create_ai_outputs_for_each_change(query, prompt, user)

      expect(query.ai_outputs.pluck(:identifier)).to eq([ "2" ])
      expect(query.ai_outputs.first.content).to include("小さい針").and include("マイクロニードル")
    end

    it "does not raise when the body is not an object" do
      user, prompt, query = assistant_records("not json")
      allow(RescueBadFormatJob).to receive(:perform_now).and_return("still bad")
      service = XAiService.new

      expect {
        service.create_ai_outputs_for_each_change(query, prompt, user)
        service.create_ai_output_for_corrected_text(query, prompt, user)
      }.not_to raise_error

      expect(query.ai_outputs).to be_empty
    end

    it "stores a quiz line that has both sides and skips one that does not" do
      user, prompt, query = assistant_records(
        {
          "entry_1" => { "content" => "", "explanation_en" => "Blank." },
          "entry_2" => { "content" => "Test → 本当の文", "explanation_en" => "Kept." },
          "assessment" => "One line was blank."
        }.to_json
      )
      prompt.define_singleton_method(:change_keyword) { "entry_" }
      blank = query.ai_outputs.build(made_note: false, identifier: "1")
      kept = query.ai_outputs.build(made_note: false, identifier: "2")
      assessment = query.ai_outputs.build(made_note: false, identifier: "assessment")

      expect(blank.assemble_content("entry_", user)).to be_nil
      kept.save_assembled_content("entry_", user)
      assessment.save_assembled_content("entry_", user)

      expect(query.ai_outputs.pluck(:identifier)).to contain_exactly("2", "assessment")
      expect(kept.content).to include("Test").and include("本当の文")
      expect(assessment.content).to eq("One line was blank.")
    end
  end
end
