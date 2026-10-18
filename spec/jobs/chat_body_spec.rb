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

  def quiz_prompt
    double(
      "prompt",
      uuid: "job-uuid",
      ai_model: "grok-4-fast-non-reasoning",
      sent_role_prompt: "role",
      raw_prompt: "raw"
    ).tap do |prompt|
      allow(prompt).to receive(:response_format).and_return("format")
    end
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

  it "discards a quiz prepare when the body is not JSON" do
    allow(XAiChat).to receive(:complete).and_return(bad_result)

    expect {
      PrepareQuizJob.perform_now(journal, quiz_prompt)
    }.not_to change(AiQuery, :count)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      "channel_job-uuid",
      target: "quizzes",
      partial: "shared/job_failure",
      locals: { message: I18n.t("ai_query.job_failed") }
    )
  end

  it "discards a quiz grade when the body is not JSON" do
    allow(XAiChat).to receive(:complete).and_return(bad_result)

    expect {
      GradeQuizJob.perform_now(journal, quiz_prompt, double("quiz"))
    }.not_to change(AiQuery, :count)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      "channel_job-uuid",
      hash_including(target: "quiz_results", partial: "shared/job_failure")
    )
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

  it "prepares a quiz from a JSON object" do
    group = Group.create!(name: "Chat body #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "chat-body-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Chat body", user: user, group: group, last_interval: 1)
    journal.entries.create!(content: "一行目")
    prompt = PrepareQuizPrompt.create!(
      raw_prompt: "entries",
      sent_role_prompt: "role",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid
    )
    result = XAiChat::Result.new(
      raw_response: '{"line_1":{"translation":"一行目 → first line","hint":"何"}}',
      parsed: { "line_1" => { "translation" => "一行目 → first line", "hint" => "何" } },
      prompt_tokens: 1,
      completion_tokens: 1,
      total_tokens: 2
    )
    allow(XAiChat).to receive(:complete).and_return(result)

    expect {
      PrepareQuizJob.perform_now(journal, prompt)
    }.to change(Quiz, :count).by(1)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      "channel_#{prompt.uuid}",
      hash_including(target: "quizzes", partial: "quizzes/output")
    )
  end
end
