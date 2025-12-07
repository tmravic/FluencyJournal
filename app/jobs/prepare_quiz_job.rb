class PrepareQuizJob < ApplicationJob
  queue_as :default

  def perform(journal, api_key, prepare_quiz_prompt)
    user = journal.user
    connection = Faraday.new(url: "https://api.x.ai")
    response = connection.post do |req|
      req.url "/v1/chat/completions"
      req.options.timeout = 120
      req.options.open_timeout = 30
      req.headers["Content-Type"] = "application/json"
      req.headers["Authorization"] = "Bearer #{api_key}"
      req.body = {
        model: prepare_quiz_prompt.ai_model,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: prepare_quiz_prompt.sent_role_prompt
          },
          {
            role: "user",
            content: prepare_quiz_prompt.raw_prompt
          },
          {
            role: "user",
            content: prepare_quiz_prompt.response_format(journal)
          }
        ]
      }.to_json
    end

    # TODO: DRY up this repetitive bit in all the jobs
    json_response = JSON.parse(response.body)
    full_token_details = json_response["usage"]
    token_data = full_token_details.slice("prompt_tokens", "completion_tokens", "total_tokens")
    # {"prompt_tokens"=>211, "completion_tokens"=>130, "total_tokens"=>341}

    response_from_x_ai = json_response["choices"][0]["message"].dig("content")

    ai_query = AiQuery.build(
      prompt_tokens: token_data["prompt_tokens"],
      completion_tokens: token_data["completion_tokens"],
      total_tokens: token_data["total_tokens"],
      raw_response: response_from_x_ai
    )

    ai_query.prompt = prepare_quiz_prompt
    ai_query.journal = journal
    ai_query.save!

    translated_response = JSON.parse(response_from_x_ai)
    # {"line_1"=>
    #    {"translation"=>
    #       "明日、彼女のお母さんに初めて会う予定です。 → Tomorrow, I have plans to meet her mother for the first time."},
    #  "line_2"=>
    #    {"translation"=>
    #       "聞きたいことのリストを作るつもりでしたが、まだそれにてをつけていません。 → I intended to make a list of things I want to ask, but I haven't gotten around to it yet."},
    #  "line_3"=>
    #    {"translation"=>
    #       "彼女によると、彼女のお母さんは甘い物が好きだそうです。チョコレートの箱を買いに行ったのですか、お仕事の休憩時間で行ったから危険なほど時間がなかったです。 → According to her, her mother likes sweet things. I went to buy a box of chocolates, but since I did it during my work break, I had dangerously little time."},
    #  "line_4"=>
    #    {"translation"=>
    #       "明日のどこかで、聞きたい質問のリストを作ろうと思っています。 → I think I'll make a list of questions I want to ask somewhere tomorrow."}}

    # Make an AiOutput for each translation of Journal#full_journal
    ai_query.create_quiz_questions(translated_response)
    quiz = Quiz.create(ai_query: ai_query, journal: journal)

    source_tag = "ai_assistant"
    ai_query_id = quiz.ai_query.id
    ai_outputs = ai_query.ai_outputs

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{prepare_quiz_prompt.uuid}",
      target: "quizzes",
      partial: "quizzes/output",
      locals: { ai_query_id:, quiz:, journal:, source_tag:, user:, ai_outputs: }
    )
  end
end
