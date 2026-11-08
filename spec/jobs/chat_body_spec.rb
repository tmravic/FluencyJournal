require "rails_helper"

RSpec.describe "chat body parsing", type: :job do
  before do
    allow_any_instance_of(ApplicationJob).to receive(:xai_api_key).and_return("key")
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
  end

  def bad_result
    XAiChat::Result.new(
      raw_response: "not json",
      parsed: nil,
      prompt_tokens: 1,
      completion_tokens: 1,
      total_tokens: 2
    )
  end

  def journal
    instance_double(Journal, user: instance_double(User))
  end

  def chat_prompt
    double(
      "prompt",
      uuid: "job-uuid",
      ai_model: "grok-4-fast-non-reasoning",
      raw_prompt: "raw"
    ).tap do |prompt|
      allow(prompt).to receive(:role_prompt).and_return("role")
      allow(prompt).to receive(:response_format).and_return("format")
    end
  end

  it "reads a fenced JSON object" do
    result = XAiChat::Result.new(
      raw_response: "```json\n{\"line_1\":{\"translation\":\"one\"}}\n```",
      parsed: nil,
      prompt_tokens: 1,
      completion_tokens: 1,
      total_tokens: 2
    )

    expect(result.parsed_object).to eq("line_1" => { "translation" => "one" })
  end

  it "discards an assistant request when the body is not JSON" do
    allow(XAiChat).to receive(:complete).and_return(bad_result)

    expect {
      AiRequestJob.perform_now(journal, chat_prompt)
    }.not_to change(AiQuery, :count)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      "channel_job-uuid",
      hash_including(target: "ai_output", partial: "shared/job_failure")
    )
  end

  it "discards a followup request when the body is not JSON" do
    allow(XAiChat).to receive(:complete).and_return(bad_result)

    expect {
      FollowupRequestJob.perform_now(instance_double(User), nil, chat_prompt, nil, "ai_assistant")
    }.not_to change(AiQuery, :count)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      "channel_job-uuid",
      hash_including(target: "followup_output_ai_assistant", partial: "shared/job_failure")
    )
  end
end
