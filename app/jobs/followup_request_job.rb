require "action_view/helpers/translation_helper"

class FollowupRequestJob < ApplicationJob
  include ActionView::Helpers::TranslationHelper
  queue_as :default

  def perform(user, journal, api_key, followup_prompt, followup_origin, source_tag)
    x_ai_service = XAiService.new(
      api_key: api_key, prompt: followup_prompt,
      user: user, journal: journal, followup_origin: followup_origin)
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

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{uuid}",
      target: "previous_queries",
      partial: "journals/previous_queries",
      locals: { journal: }
      # in the case of a note journal isn't used
      # need origin: or reference: instead
    )
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

  def parse_response_from_x_api(response)
    JSON.parse(response.body)
    # {"id"=>"12f4fceb-5b18-610d-6d08-50b474977829",
    #  "object"=>"chat.completion",
    #  "created"=>1770524310,
    #  "model"=>"grok-4-fast-non-reasoning",
    #  "choices"=>
    #    [{"index"=>0,
    #      "message"=>
    #        {"role"=>"assistant",
    #         "content"=>
    #           "{\"answer_1\":{\"content\":\"壁の塗装が剥げ落ちるほど古い日本酒の醸造所を訪れました。\",\"explanation_en\":\"This rephrasing uses '塗装' (tosō) for 'paint' to vary the vocabulary, '剥げ落ちる' (hageochiru) for a more descriptive peeling action, and '醸造所' (jōzōsho) to specify 'sake brewery' more clearly. '訪れました' (tazunemashita) is a synonym for '行きました' to change the verb while keeping the meaning intact.\"},\"answer_2\":{\"content\":\"古くて壁のペンキがめくれていた日本酒の醸造所に行きました。\",\"explanation_en\":\"Here, the sentence structure is adjusted by placing '古くて' (furukute) at the beginning to emphasize age, and 'めくれていた' (mekureteita) as a synonym for 'peeling' to make it sound more natural. '醸造所' adds specificity to the location.\"},\"answer_3\":{\"content\":\"日本酒の醸造所で、壁のペンキが剥げた古い建物を見学しました。\",\"explanation_en\":\"This version breaks the sentence into parts for better flow, using '見学しました' (kenkyō shimashita) instead of '行きました' to imply 'visited for viewing,' and '建物' (tatemono) to describe the building, providing a slightly more detailed and varied expression.\"}}",
    #         "refusal"=>nil},
    #      "finish_reason"=>"stop"}],
    #  "usage"=>
    #    {
    #      "prompt_tokens"=>507, "completion_tokens"=>326, "total_tokens"=>833,
    #      "prompt_tokens_details"=>{"text_tokens"=>507, "audio_tokens"=>0, "image_tokens"=>0, "cached_tokens"=>161},
    #      "completion_tokens_details"=>
    #        {
    #          "reasoning_tokens"=>0, "audio_tokens"=>0, "accepted_prediction_tokens"=>0, "rejected_prediction_tokens"=>0
    #        },
    #      "num_sources_used"=>0, "cost_in_usd_ticks"=>2402500}, "system_fingerprint"=>"fp_f7a6b84626"
    # }
  end
end

private

def handle_error(exception, context)
  Rails.logger.error("FollowupRequestJob error: #{context}: #{exception.message}")
  Rails.logger.error(exception.backtrace.join("\n"))
end
