require "action_view/helpers/translation_helper"

class FollowupRequestJob < ApplicationJob
  include ActionView::Helpers::TranslationHelper
  queue_as :default

  def perform(user, journal, followup_prompt, followup_origin, source_tag)
    x_ai_service = XAiService.new(
      api_key: xai_api_key,
      prompt: followup_prompt,
      user: user,
      journal: journal,
      followup_origin: followup_origin
    )
    ai_query = x_ai_service.call

    followup = followup_prompt.followup
    ai_query_id = ai_query.id
    uuid = followup_prompt.uuid
    followup_text = t("followup.followup_answer")

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{uuid}",
      target: "followup_output_#{source_tag}",
      partial: "followups/output",
      locals: { followup_text:, ai_query_id:, uuid:, user:, followup:, source_tag: }
    )

    if journal
      Turbo::StreamsChannel.broadcast_update_to(
        "channel_#{uuid}",
        target: "previous_queries",
        partial: "journals/previous_queries",
        locals: { journal: }
        # in the case of a note journal isn't used
        # need origin: or reference: instead
      )
    end
  rescue Faraday::ConnectionFailed => e
    handle_error(e, "Connection failed to Xai API")
  rescue JSON::ParserError => e
    handle_error(e, "Failed to parse JSON response")
  rescue ActiveRecord::RecordInvalid => e
    handle_error(e, "ActiveRecord validation failed")
  rescue StandardError => e
    handle_error(e, "An unexpected error occurred")
  end

  private

  def handle_error(exception, context)
    Rails.logger.error("FollowupRequestJob error: #{context}: #{exception.message}")
    Rails.logger.error(exception.backtrace.join("\n"))
  end
end
