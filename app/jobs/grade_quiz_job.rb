class GradeQuizJob < ApplicationJob
  # A body that is not a JSON object will not become one on its own.
  discard_on JSON::ParserError

  queue_as :default

  def perform(journal, quiz_result_prompt, quiz)
    user = journal.user
    result = XAiChat.complete(
      model: quiz_result_prompt.ai_model,
      instructions: quiz_result_prompt.sent_role_prompt,
      user_messages: [
        quiz_result_prompt.raw_prompt,
        quiz_result_prompt.response_format(user, journal, quiz)
      ]
    )

    result.parsed_object

    ai_query = AiQuery.from_chat(
      raw_response: result.raw_response, token_data: result.token_data,
      prompt: quiz_result_prompt, journal: journal
    )
    ai_query.change_count = ai_query.count_changes(quiz_result_prompt.change_keyword)

    # {"entry_1"=>
    #   {"content"=>"彼女のお母さんに会いました。 → 彼女のお母さんに会いました。",
    #    "explanation_en"=> "This translation is identical to the original and accurately conveys the meaning of meeting her mother in grammatically correct Japanese. No issues."},
    # "entry_2"=>
    #   {"content"=>"３人で中目黒にピザを食べました。 → ３人で中目黒にピザを食べました。",
    #    "explanation_en"=> "This translation matches the original exactly, correctly expressing that three people ate pizza in Nakameguro. Perfect grammar and meaning."},
    # "assessment"=>
    #   "The quiz answers are perfectly accurate overall, with no mistakes in meaning, grammar, or word choice. They replicate the original journal entries precisely while aligning with the English quiz questions."}

    # Grade query, outputs, and grading_ai_query_id commit together so a
    # deadlock rolls the query back instead of leaving a second child.
    ActiveRecord::Base.transaction do
      ai_query.save!

      # Make an AiOutput for each change in the journal query
      (1..ai_query.change_count.to_i).each do |number|
        ai_query.add_assembled_output(identifier: number.to_s, role: :line, user: journal.user)
      end

      # Make one more AiOutput for the Assessment
      ai_query.add_assembled_output(identifier: "assessment", role: :assessment, user: journal.user)

      quiz.update(grading_ai_query_id: ai_query.id)
    end

    source_tag = SourceTag::AI_ASSISTANT
    assessment = ai_query.assessment
    ai_query_id = ai_query.id

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
