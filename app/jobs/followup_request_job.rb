class FollowupRequestJob < ApplicationJob
  queue_as :default

  def perform(user, journal, api_key, followup_prompt, followup_origin, source_tag)

    connection = Faraday.new(url: 'https://api.openai.com')
    response = connection.post do |req|
      req.url "/v1/chat/completions"
      req.options.timeout = 30
      req.options.open_timeout = 30
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = "Bearer #{api_key}"
      req.body = {
        model: followup_prompt.ai_model,
        response_format: { type: "json_object" },
        messages: [
          {
            role: 'system',
            content: followup_prompt.role_prompt(user)
          },
          {
            role: 'user',
            content: followup_prompt.raw_prompt
          },
          {
            role: 'user',
            content: followup_prompt.response_format(user)
          }
        ],
      }.to_json
    end

    json_response = JSON.parse(response.body)

    full_token_details = json_response['usage']

    token_data = full_token_details.slice("prompt_tokens", "completion_tokens", "total_tokens")

    response_from_open_ai = json_response['choices'][0]['message'].dig("content")

    ai_query = AiQuery.build(
      prompt_tokens: token_data["prompt_tokens"],
      completion_tokens: token_data["completion_tokens"],
      total_tokens: token_data["total_tokens"],
      raw_response: response_from_open_ai
    )

    ai_query.change_count = ai_query.count_changes(followup_prompt.change_keyword)
    ai_query.prompt = followup_prompt
    ai_query.journal = journal if journal
    # If this is a followup on a Note it won't be connected to any journal.
    followup = followup_prompt.followup

    ai_query.followups.push(followup)
    if ai_query.save!
      if followup_origin.is_a?(Entry)
        followup_origin.followups.push(followup)
      elsif followup_origin.is_a?(AiOutput)
        followup_origin.followups.push(followup)
      elsif followup_origin.is_a?(Note)
        followup_origin.followups.push(followup)
      end
    end

    # Make an AiOutput for each feedback or example in the followup query
    (1..ai_query.change_count).each do |count|
      ai_query.ai_outputs.create(
        made_note: false,
        identifier: count.to_s
      ).tap do |ai_output|
        ai_output.content = ai_output.assemble_content(followup_prompt.change_keyword, user)
        # "お寺に参拝して、「好きな女の子が私の彼女になりますように」と祈りました。\n('参拝する' is another way to say 'to visit a temple' that carries the meaning of worshipping or paying respect.)"
        ai_output.save!
      end
    end

    ai_query_id = ai_query.id
    uuid = followup_prompt.uuid
    followup_text = "Followup #{followup_prompt.change_keyword.titleize.strip}"

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{uuid}",
      target: "followup_output_#{source_tag}",
      partial: 'followups/output',
      locals: { followup_text:, ai_query_id:, uuid:, user:, followup:, source_tag: }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{uuid}",
      target: 'previous_queries',
      partial: 'journals/previous_queries',
      locals: { journal: }
      # in the case of a note journal isn't used
      # need origin: or reference: instead
    )
  rescue Faraday::ConnectionFailed => e
    handle_error(e, "Connection failed to OpenAI API")
  rescue JSON::ParserError => e
    handle_error(e, "Failed to parse JSON response")
  rescue ActiveRecord::RecordInvalid => e
    handle_error(e, "ActiveRecord validation failed")
  rescue StandardError => e
    handle_error(e, "An unexpected error occurred")
  end
end

private

def handle_error(exception, context)
  Rails.logger.error("FollowupRequestJob error: #{context}: #{exception.message}")
  Rails.logger.error(exception.backtrace.join("\n"))
end

