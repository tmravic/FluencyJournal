class GradeQuizJob < ApplicationJob
  queue_as :default

  def perform(journal, quiz_result_prompt, quiz)
    user = journal.user
    result = XAiChat.complete(
      model: quiz_result_prompt.ai_model,
      instructions: quiz_result_prompt.sent_role_prompt,
      user_messages: [
        quiz_result_prompt.raw_prompt,
        quiz_result_prompt.response_format(journal, quiz, user)
      ]
    )

    ai_query = AiQuery.build(
      prompt_tokens: result.prompt_tokens,
      completion_tokens: result.completion_tokens,
      total_tokens: result.total_tokens,
      raw_response: result.raw_response
    )

    ai_query.prompt = quiz_result_prompt
    ai_query.change_count = ai_query.count_changes(quiz_result_prompt.change_keyword)
    ai_query.journal = journal
    ai_query.save!

    # {"entry_1"=>
    #   {"content"=>"彼女のお母さんに会いました。 → 彼女のお母さんに会いました。",
    #    "explanation_en"=> "This translation is identical to the original and accurately conveys the meaning of meeting her mother in grammatically correct Japanese. No issues."},
    # "entry_2"=>
    #   {"content"=>"３人で中目黒にピザを食べました。 → ３人で中目黒にピザを食べました。",
    #    "explanation_en"=> "This translation matches the original exactly, correctly expressing that three people ate pizza in Nakameguro. Perfect grammar and meaning."},
    # "assessment"=>
    #   "The quiz answers are perfectly accurate overall, with no mistakes in meaning, grammar, or word choice. They replicate the original journal entries precisely while aligning with the English quiz questions."}

    # Make an AiOutput for each change in the journal query
    count = ai_query.change_count.to_i
    if count >= 1
      (1..count).each do |number|
        ai_query.ai_outputs.build(
          made_note: false,
          identifier: number.to_s
        ).save_assembled_content(quiz_result_prompt.change_keyword, journal.user)
      end
    end

    # Make one more AiOutput for the Assessment
    ai_query.ai_outputs.build(
      made_note: false,
      identifier: "assessment"
    ).save_assembled_content(quiz_result_prompt.change_keyword, journal.user)

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

  private

  def failure_stream_and_target
    _journal, quiz_result_prompt, _quiz = arguments
    return [nil, nil] unless quiz_result_prompt.respond_to?(:uuid)

    [ "channel_#{quiz_result_prompt.uuid}", "quiz_results" ]
  end
end
