module QuizzesHelper
  def build_quiz_answer(quiz, ai_output)
    quiz.quiz_answers.build(ai_output: ai_output)
  end

  def set_assessment_output(ai_query)
    ai_query.find_ai_output_by_identifier("assessment") if ai_query
  end

  def render_ai_query_entry_content(ai_query, identifier, entry_keyword, user, quiz, html: false)
    output = ai_query.find_ai_output_by_identifier(identifier)
    return "" unless output

    contents_hash = create_contents_hash(ai_query, identifier, entry_keyword, user)
    if html
      content_tag(:div) do
        concat content_tag(:div, contents_hash[:content_first])
        concat tag.p("↓")
        concat content_tag(:div, contents_hash[:content_last])
        concat content_tag(:div, "(#{contents_hash[:explanation]})")
      end
    else
      # Plain text fallback (e.g., for non-HTML contexts)
      output.content
    end
  end

  def create_contents_hash(ai_query, identifier, change_keyword, user = nil)
    if identifier == "corrected_text"
      learning_language, corrected_sentence = get_ai_output_correction_variables(ai_query)
    elsif rendering_followup?(ai_query, identifier, change_keyword)
      content, explanation = get_followup_variables(ai_query, identifier, change_keyword, user)
    else
      content_first, content_last, explanation = get_ai_output_change_variables(ai_query, identifier, change_keyword)
    end

    { learning_language:, corrected_sentence:, content_first:, content_last:, content:, explanation: }
  end
end