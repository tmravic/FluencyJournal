class GradeQuizJob < ApplicationJob
  queue_as :default

  def perform(journal, quiz_result_prompt, quiz)
    user = journal.user

    connection = Faraday.new(url: "https://api.x.ai")
    response = connection.post do |req|
      req.url "/v1/chat/completions"
      req.options.timeout = 120
      req.options.open_timeout = 30
      req.headers["Content-Type"] = "application/json"
      req.headers["Authorization"] = "Bearer #{xai_api_key}"
      req.body = {
        model: quiz_result_prompt.ai_model,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: quiz_result_prompt.sent_role_prompt
          },
          {
            role: "user",
            content: quiz_result_prompt.raw_prompt
          },
          {
            role: "user",
            content: quiz_result_prompt.response_format(journal, quiz, user)
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

    ai_query.prompt = quiz_result_prompt
    ai_query.change_count = ai_query.count_changes(quiz_result_prompt.change_keyword)
    ai_query.journal = journal
    ai_query.save!

    graded_response = JSON.parse(response_from_x_ai)
    # {"entry_1"=>
    #   {"content"=>"彼女のお母さんに会いました。 → 彼女のお母さんに会いました。",
    #    "explanation_en"=> "This translation is identical to the original and accurately conveys the meaning of meeting her mother in grammatically correct Japanese. No issues."},
    # "entry_2"=>
    #   {"content"=>"３人で中目黒にピザを食べました。 → ３人で中目黒にピザを食べました。",
    #    "explanation_en"=> "This translation matches the original exactly, correctly expressing that three people ate pizza in Nakameguro. Perfect grammar and meaning."},
    # "assessment"=>
    #   "The quiz answers are perfectly accurate overall, with no mistakes in meaning, grammar, or word choice. They replicate the original journal entries precisely while aligning with the English quiz questions."}

    # Make an AiOutput for each change in the journal query
    (1..ai_query.change_count).each do |count|
      ai_query.ai_outputs.create(
        made_note: false,
        identifier: count.to_s
      ).tap do |ai_output|
        ai_output.content = ai_output.assemble_content(quiz_result_prompt.change_keyword, journal.user)
        ai_output.save!
      end
    end

    # Make one more AiOutput for the Assessment
    ai_query.ai_outputs.create(
      made_note: false,
      identifier: "assessment"
    ).tap do |ai_output|
      ai_output.content = ai_output.assemble_content(quiz_result_prompt.change_keyword, journal.user)
      ai_output.save!
    end

    source_tag = "ai_assistant"
    assessment = ai_query.assessment
    ai_query_id = ai_query.id
    quiz.update(grading_ai_query_id: ai_query_id)
    quiz.grading_ai_query.quizzes.push(quiz)

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{quiz_result_prompt.uuid}",
      target: "quiz_results",
      partial: "quizzes/graded_output",
      locals: { assessment:, ai_query_id:, source_tag:, user:, quiz: }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{quiz_result_prompt.uuid}",
      target: "previous_queries",
      partial: "journals/previous_queries",
      locals: { journal: }
    )
  end
end
