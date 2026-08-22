require "rails_helper"

RSpec.describe AiRequestJob, type: :job do
  it "sends journal corrections through XAiService" do
    user = instance_double(User)
    journal = instance_double(Journal, user: user)
    entry_prompt = instance_double(EntryPrompt, uuid: "abc")
    ai_query = instance_double(AiQuery, corrected_text: "corrected", id: 1)
    service = instance_double(XAiService, call: ai_query)

    allow_any_instance_of(described_class).to receive(:xai_api_key).and_return("key")
    expect(XAiService).to receive(:new).with(
      api_key: "key",
      prompt: entry_prompt,
      user: user,
      journal: journal
    ).and_return(service)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)

    described_class.perform_now(journal, entry_prompt)
  end
end
