class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  # ruby_llm already retries these inside one HTTP call. This retries the job.
  # The last attempt raises, and after_discard updates the page.
  TRANSIENT_AI_ERRORS = [
    RubyLLM::RateLimitError,
    RubyLLM::ServerError,
    RubyLLM::ServiceUnavailableError,
    Faraday::TimeoutError
  ].freeze

  retry_on(*TRANSIENT_AI_ERRORS, wait: :polynomially_longer, attempts: 5)

  after_discard do |_job, error|
    broadcast_job_failure(error)
  end

  private

  def xai_api_key
    Rails.application.credentials.xai.fetch(:api_key)
  end

  def broadcast_job_failure(error)
    Rails.logger.error("#{self.class.name} failed: #{error.class}: #{error.message}")

    stream_name, target = failure_stream_and_target
    return if stream_name.blank? || target.blank?

    Turbo::StreamsChannel.broadcast_update_to(
      stream_name,
      target: target,
      partial: "shared/job_failure",
      locals: { message: I18n.t("ai_query.job_failed") }
    )
  rescue StandardError => broadcast_error
    Rails.logger.error(
      "#{self.class.name} could not broadcast the failure: #{broadcast_error.class}: #{broadcast_error.message}"
    )
  end

  # Jobs that render into a Turbo frame override this with [stream, target].
  def failure_stream_and_target
    [nil, nil]
  end
end
