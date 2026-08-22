class AiRequestJob < ApplicationJob
  queue_as :default

  def perform(journal, entry_prompt)
    user = journal.user
    x_ai_service = XAiService.new(api_key: xai_api_key, prompt: entry_prompt, user: user, journal: journal)
    ai_query = x_ai_service.call

    source_tag = "ai_assistant"
    corrected_text = ai_query.corrected_text
    ai_query_id = ai_query.id

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{entry_prompt.uuid}",
      target: "ai_output",
      partial: "ai_queries/output",
      locals: { corrected_text:, ai_query_id:, source_tag:, user: }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{entry_prompt.uuid}",
      target: "previous_queries",
      partial: "journals/previous_queries",
      locals: { journal: }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{entry_prompt.uuid}",
      target: "ai_request_form_delete_buttons",
      partial: "ai_queries/delete_buttons",
      locals: { journal:, ai_query: }
    )
  end
end
