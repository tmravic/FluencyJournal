module SharedServiceMethods
  def save_followup_based_on_origin(ai_query, followup, followup_origin)
    ai_query.followups.push(followup)
    if ai_query.save!
      if followup_origin.is_a?(Entry)
        followup_origin.followups.push(followup)
      elsif followup_origin.is_a?(AiOutput)
        followup_origin.followups.push(followup)
      elsif followup_origin.is_a?(Note)
        followup_origin.followups.push(followup)
      elsif followup_origin.is_a?(JournalFollowup)
        followup_origin.followups.push(followup)
      end
    end
  end

  def build_ai_query(response_from_model, token_data, prompt, journal)
    ai_query = AiQuery.build(
      prompt_tokens: token_data["prompt_tokens"],
      completion_tokens: token_data["completion_tokens"],
      total_tokens: token_data["total_tokens"],
      raw_response: response_from_model
    )

    ai_query.change_count = ai_query.count_changes(prompt.change_keyword)
    ai_query.prompt = prompt
    ai_query.journal = journal if journal
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
