class PrepareQuizJob < ApplicationJob
  # A body that is not a JSON object will not become one on its own.
  discard_on JSON::ParserError

  queue_as :default

  def perform(journal, prepare_quiz_prompt)
    user = journal.user
    result = XAiChat.complete(
      model: prepare_quiz_prompt.ai_model,
      instructions: prepare_quiz_prompt.sent_role_prompt,
      user_messages: [
        prepare_quiz_prompt.raw_prompt,
        prepare_quiz_prompt.response_format(user, journal, nil)
      ]
    )

    translated_response = result.parsed_object

    ai_query = AiQuery.from_chat(
      raw_response: result.raw_response, token_data: result.token_data,
      prompt: prepare_quiz_prompt, journal: journal
    )
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

    expected = journal.entry_texts.count
    # Query, quiz, questions, and hints commit together. A deadlock rolls
    # the query back, and reset cannot see hints that are still inserting.
    quiz = ActiveRecord::Base.transaction do
      ai_query.save!
      created = Quiz.create!(ai_query: ai_query, journal: journal)
      ai_query.create_quiz_questions(translated_response, expected_count: expected, quiz: created)
      created
    end

    source_tag = SourceTag::AI_ASSISTANT
    ai_query_id = quiz.ai_query.id
    ai_outputs = ai_query.ai_outputs.sort_by { |output| output.identifier.to_i }

    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{prepare_quiz_prompt.uuid}",
      target: "quizzes",
      partial: "quizzes/output",
      locals: { ai_query_id:, quiz:, journal:, source_tag:, user:, ai_outputs: }
    )
  end

  private

  def failure_stream_and_target
    _journal, prepare_quiz_prompt = arguments
    return [nil, nil] unless prepare_quiz_prompt.respond_to?(:uuid)

    [ "channel_#{prepare_quiz_prompt.uuid}", "quizzes" ]
  end
end
