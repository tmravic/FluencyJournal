require "rails_helper"

RSpec.describe "one prompt child", type: :job do
  def create_prompt
    EntryPrompt.create!(
      raw_prompt: "prompt",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
  end

  it "rejects a second ai query and a second followup for the same prompt" do
    prompt = create_prompt
    AiQuery.create!(prompt: prompt, raw_response: "{}")
    Followup.create!(prompt: prompt, source_tag: "notes_box")

    expect {
      ActiveRecord::Base.transaction(requires_new: true) do
        AiQuery.create!(prompt: prompt, raw_response: "{}")
      end
    }.to raise_error(ActiveRecord::RecordNotUnique)

    expect {
      ActiveRecord::Base.transaction(requires_new: true) do
        Followup.create!(prompt: prompt, source_tag: "notes_box")
      end
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
