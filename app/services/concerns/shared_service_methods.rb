module SharedServiceMethods
  def build_ai_query(response_from_model, token_data, entry_prompt, journal)
    ai_query = AiQuery.build(
      prompt_tokens: token_data["prompt_tokens"],
      completion_tokens: token_data["completion_tokens"],
      total_tokens: token_data["total_tokens"],
      raw_response: response_from_model
    )

    ai_query.prompt = entry_prompt
    ai_query.change_count = ai_query.count_changes(entry_prompt.change_keyword)
    ai_query.journal = journal
    ai_query.save!
    ai_query
  end

  def create_ai_outputs_for_each_change(ai_query, entry_prompt, journal)
    (1..ai_query.change_count).each do |count|
      ai_query.ai_outputs.create(
        made_note: false,
        identifier: count.to_s
      ).tap do |ai_output|
        ai_output.content = ai_output.assemble_content(entry_prompt.change_keyword, journal.user)
        ai_output.save!
      end
    end
  end

  def create_ai_output_for_corrected_text(ai_query, entry_prompt, journal)
    ai_query.ai_outputs.create(
      made_note: false,
      identifier: "corrected_text"
    ).tap do |ai_output|
      ai_output.content = ai_output.assemble_content(entry_prompt.change_keyword, journal.user)
      ai_output.save!
    end
  end
end