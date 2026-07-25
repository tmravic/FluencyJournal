class PrepareQuizHintJob < ApplicationJob
  queue_as :default

  def perform(quiz, api_key)
    uuid = SecureRandom.uuid
    journal = quiz.journal
    user = quiz.journal.user

    quiz_hint_prompt = QuizHintPrompt.build(
      raw_prompt: journal.full_journal,
      ai_model: "grok-4-fast-non-reasoning",
      uuid: uuid,
      base_content: journal.full_journal.join,
      user_generated_content: journal.full_journal.join
    )

    quiz_hint_prompt.sent_role_prompt = quiz_hint_prompt.role_prompt(user, journal)
    if quiz_hint_prompt.save!
      connection = Faraday.new(url: "https://api.x.ai")
      response = connection.post do |req|
        req.url "/v1/chat/completions"
        req.options.timeout = 120
        req.options.open_timeout = 30
        req.headers["Content-Type"] = "application/json"
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.body = {
          model: quiz_hint_prompt.ai_model,
          response_format: { type: "json_object" },
          messages: [
            {
              role: "system",
              content: quiz_hint_prompt.sent_role_prompt
            },
            {
              role: "user",
              content: quiz_hint_prompt.raw_prompt
            },
            {
              role: "user",
              content: quiz_hint_prompt.response_format(user, journal)
            }
          ]
        }.to_json
      end

      json_response = JSON.parse(response.body)
      full_token_details = json_response["usage"]
      token_data = full_token_details.slice("prompt_tokens", "completion_tokens", "total_tokens")
      # {"prompt_tokens"=>211, "completion_tokens"=>130, "total_tokens"=>341}

      response_from_x_ai = json_response["choices"][0]["message"].dig("content")

      ai_query = AiQuery.build(prompt_tokens: token_data["prompt_tokens"], completion_tokens: token_data["completion_tokens"], total_tokens: token_data["total_tokens"], raw_response: response_from_x_ai)

      ai_query.prompt = quiz_hint_prompt
      ai_query.journal = journal
      ai_query.save!

      translated_response = JSON.parse(response_from_x_ai)
      ai_query.create_quiz_hints(translated_response, quiz)

      # Reuse the prepare-quiz stream so the open quiz page receives this update.
      stream_name = "channel_#{quiz.ai_query.prompt.uuid}"
      ai_outputs = quiz.ai_query.ai_outputs.sort_by { |o| o.identifier.to_i }

      ai_outputs.each do |quiz_entry|
        Turbo::StreamsChannel.broadcast_update_to(
          stream_name,
          target: "show_hint_button_#{quiz_entry.id}",
          partial: "quiz_answers/show_hint_button",
          locals: { journal: journal, quiz: quiz, quiz_entry: quiz_entry, enabled: true }
        )
      end
    end

  end
end
