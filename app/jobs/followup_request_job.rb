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
  end

  private

  def failure_stream_and_target
    _user, _journal, followup_prompt, _origin, source_tag = arguments
    return [nil, nil] unless followup_prompt.respond_to?(:uuid)

    [ "channel_#{followup_prompt.uuid}", "followup_output_#{source_tag}" ]
  end
end
