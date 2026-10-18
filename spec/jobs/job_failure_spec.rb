require "rails_helper"

RSpec.describe "AI job failures", type: :job do
  around do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = original
  end

  before do
    allow_any_instance_of(ApplicationJob).to receive(:xai_api_key).and_return("key")
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
  end

  def prompt
    double(
      "prompt",
      uuid: "job-uuid",
      ai_model: "grok-4-fast-non-reasoning",
      sent_role_prompt: "role",
      raw_prompt: "raw"
    ).tap do |prompt_double|
      allow(prompt_double).to receive(:response_format).and_return("format")
    end
  end

  def journal
    instance_double(Journal, user: instance_double(User))
  end

  def run_job(job_class)
    case job_class.name
    when "FollowupRequestJob"
      job_class.perform_now(instance_double(User), nil, prompt, nil, "ai_assistant")
    when "AiRequestJob"
      job_class.perform_now(journal, prompt)
    when "PrepareQuizJob"
      job_class.perform_now(journal, prompt)
    when "GradeQuizJob"
      job_class.perform_now(journal, prompt, double("quiz"))
    end
  end

  def stub_failure(job_class, error)
    if job_class == PrepareQuizJob || job_class == GradeQuizJob
      allow(XAiChat).to receive(:complete).and_raise(error)
    else
      allow(XAiService).to receive(:new).and_raise(error)
    end
  end

  describe "a permanent failure" do
    {
      FollowupRequestJob => "followup_output_ai_assistant",
      AiRequestJob => "ai_output",
      PrepareQuizJob => "quizzes",
      GradeQuizJob => "quiz_results"
    }.each do |job_class, target|
      it "raises from #{job_class} and updates #{target}" do
        stub_failure(job_class, StandardError.new("boom"))

        expect { run_job(job_class) }.to raise_error(StandardError, "boom")
        expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
          "channel_job-uuid",
          target: target,
          partial: "shared/job_failure",
          locals: { message: I18n.t("ai_query.job_failed") }
        )
      end
    end
  end

  it "retries a rate limit without updating the page" do
    stub_failure(FollowupRequestJob, RubyLLM::RateLimitError.new("slow down"))
    expect_any_instance_of(FollowupRequestJob).to receive(:retry_job)

    expect { run_job(FollowupRequestJob) }.not_to raise_error
    expect(Turbo::StreamsChannel).not_to have_received(:broadcast_update_to)
  end

  it "retries a Faraday timeout without updating the page" do
    stub_failure(PrepareQuizJob, Faraday::TimeoutError.new("timed out"))
    expect_any_instance_of(PrepareQuizJob).to receive(:retry_job)

    expect { run_job(PrepareQuizJob) }.not_to raise_error
    expect(Turbo::StreamsChannel).not_to have_received(:broadcast_update_to)
  end

  it "updates the page when the rate-limit retries are finished" do
    stub_failure(GradeQuizJob, RubyLLM::RateLimitError.new("slow down"))
    job = GradeQuizJob.new(journal, prompt, double("quiz"))
    job.exception_executions[ApplicationJob::TRANSIENT_AI_ERRORS.to_s] = 4

    expect { job.perform_now }.to raise_error(RubyLLM::RateLimitError)
    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      "channel_job-uuid",
      target: "quiz_results",
      partial: "shared/job_failure",
      locals: { message: "The request failed. Please try again." }
    )
  end

  it "renders the failure in the same card the processing state uses" do
    html = ApplicationController.render(
      partial: "shared/job_failure",
      locals: { message: I18n.t("ai_query.job_failed") }
    )

    expect(html).to include(%(class="card"))
    expect(html).to include("The request failed. Please try again.")
  end

  it "registers a retry for each transient provider error" do
    handlers = ApplicationJob.rescue_handlers.map(&:first)

    expect(handlers).to include(
      "RubyLLM::RateLimitError",
      "RubyLLM::ServerError",
      "RubyLLM::ServiceUnavailableError",
      "Faraday::TimeoutError"
    )
  end
end
