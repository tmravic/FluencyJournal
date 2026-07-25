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
      render_ai_query_entry_reference_text(ai_query, identifier, entry_keyword, user)
    end
  end

  def quiz_graded_entries_reference_text(ai_query, user)
    entry_keyword = ai_query.prompt.change_keyword
    assessment_output = set_assessment_output(ai_query)

    ai_query.ai_outputs
      .reject { |output| output == assessment_output }
      .sort_by { |output| output.identifier.to_i }
      .map do |output|
        [
          "#{I18n.t("entry.entry", number: output.identifier)}:",
          render_ai_query_entry_reference_text(ai_query, output.identifier, entry_keyword, user)
        ].join("\n")
      end
      .join("\n\n")
  end

  def render_ai_query_entry_reference_text(ai_query, identifier, entry_keyword, user)
    contents_hash = create_contents_hash(ai_query, identifier, entry_keyword, user)
    return "" unless contents_hash[:content_first].present? && contents_hash[:content_last].present?

    [
      contents_hash[:content_first],
      "↓",
      contents_hash[:content_last],
      "(#{contents_hash[:explanation]})"
    ].join("\n")
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

  def start_preparing_hints(quiz)
    @api_key = Rails.application.credentials.xai[:api_key]
    PrepareQuizHintJob.perform_later(quiz, @api_key, quiz.journal.user)
  end
end