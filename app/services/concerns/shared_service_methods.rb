module SharedServiceMethods
  def build_ai_query(response_from_model, token_data, prompt, journal)
    ai_query = AiQuery.from_chat(
      raw_response: response_from_model, token_data: token_data, prompt: prompt, journal: journal
    )
    ai_query.change_count = ai_query.count_changes(prompt.change_keyword)
    ai_query.save!
    ai_query
  end

  def create_ai_outputs_for_each_change(ai_query, prompt, user)
    count = ai_query.change_count.to_i
    return if count < 1

    (1..count).each do |number|
      ai_query.ai_outputs.build(
        made_note: false,
        identifier: number.to_s,
        role: :line
      ).save_assembled_content(prompt.change_keyword, user)
    end
  end

  def create_ai_output_for_corrected_text(ai_query, prompt, user)
    ai_query.ai_outputs.build(
      made_note: false,
      identifier: "corrected_text",
      role: :corrected_text
    ).save_assembled_content(prompt.change_keyword, user)
  end
end
