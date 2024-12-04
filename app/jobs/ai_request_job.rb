class AiRequestJob < ApplicationJob
  queue_as :default

  def perform(ai_request_params, api_key)
    connection = Faraday.new(url: 'https://api.openai.com')
    response = connection.post do |req|
      req.url "/v1/chat/completions"
      req.options.timeout = 120         # Increase timeout to 120 seconds
      req.options.open_timeout = 30    # Set an open timeout
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = "Bearer #{api_key}"
      req.body = {
        model: "gpt-4o",
        response_format: { type: "json_object" },
        messages: [
          {
            role: 'system',
            content: 'You are a helpful Japanese teacher whose job it is to fix grammar mistakes and reword journal entries into more natural and correct Japanese.'
          },
          {
            role: 'user',
            content: ai_request_params[:prompt]
          },
          {
            role: 'user',
            content: 'Include json marker and return json in this exact format (matching the number of changes) { { change_1: { content: "... → ...", explanation_en: "...", change_2: { content: "... → ...", explanation_en: "...", change_3: { content: "... → ...", explanation_en: "...", ..., corrected_text: { "..." }, } }'
          }
        ],
      }.to_json
    end

    json_response = JSON.parse(response.body)
    # {"id"=>"chatcmpl-APprvO8a1j6L0MTXFdzduLl9802KC",
    #  "object"=>"chat.completion",
    #  "created"=>1730720947,
    #  "model"=>"gpt-4o-2024-08-06",
    #  "choices"=>
    #    [{"index"=>0,
    #      "message"=>{"role"=>"assistant", "content"=>"{ \"corrected_text\": \"今日は弁当を作りました。風邪気味だったので、家で休みました。\" }", "refusal"=>nil},
    #      "logprobs"=>nil,
    #      "finish_reason"=>"stop"}],
    #  "usage"=>
    #    {"prompt_tokens"=>80,
    #     "completion_tokens"=>29,
    #     "total_tokens"=>109,
    #     "prompt_tokens_details"=>{"cached_tokens"=>0},
    #     "completion_tokens_details"=>{"reasoning_tokens"=>0}},
    #  "system_fingerprint"=>"fp_159d8341cc"}

    response_from_open_ai = json_response['choices'][0]['message'].dig("content")
    # {"corrected_text"=>"伊藤さん、いつもお世話になっております。お休みの日にご連絡して申し訳ございません。昨日、マイページの日程調整画面でフレクトの最終面談の候補日（5月1日、5月7日の19:30）を入力しました。ただし、5月2日に別の予定が入ってしまったため、その日はフレクトの最終面談を行えません。代わりに5月8日を候補日として提案したいと思います。5月2日を除外しても可能でしょうか。ご連絡お待ちしております。"}
    generated_idea = JSON.parse(response_from_open_ai)#.dig("corrected_text")
    uuid = ai_request_params[:uuid]
    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{uuid}",
      target: 'ai_output',
      partial: 'ai/output',
      locals: { generated_idea: }
    )
  end
end