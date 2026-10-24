module QuizzesHelper
  def build_quiz_answer(quiz, ai_output)
    quiz.quiz_answers.build(ai_output: ai_output)
  end

  def set_assessment_output(ai_query)
    ai_query.ai_outputs.assessment.first if ai_query
  end

  def render_ai_query_entry_content(ai_query, identifier, entry_keyword, user, quiz, html: false)
    output = ai_query.find_ai_output_by_identifier(identifier)
    return "" unless output

    contents_hash = create_contents_hash(ai_query, identifier, entry_keyword, user)
    if html
      render_quiz_entry_html(contents_hash)
    else
      render_ai_query_entry_reference_text(ai_query, identifier, entry_keyword, user)
    end
  end

  def quiz_graded_entries_reference_text(ai_query, user)
    entry_keyword = ai_query.prompt.change_keyword
    assessment_output = set_assessment_output(ai_query)

    ai_query.ai_outputs
      .reject { |output| output == assessment_output }
      .sort_by { |output| output.line_number.to_i }
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
    if quiz_entry_has_two_sides?(contents_hash)
      [
        contents_hash[:content_first],
        "↓",
        contents_hash[:content_last],
        "(#{contents_hash[:explanation]})"
      ].join("\n")
    elsif contents_hash[:content].present?
      "#{contents_hash[:content]}\n(#{contents_hash[:explanation]})"
    else
      ""
    end
  end

  def render_quiz_entry_html(contents_hash)
    if quiz_entry_has_two_sides?(contents_hash)
      content_tag(:div) do
        concat content_tag(:div, contents_hash[:content_first])
        concat tag.p("↓")
        concat content_tag(:div, contents_hash[:content_last])
        concat content_tag(:div, "(#{contents_hash[:explanation]})")
      end
    else
      content_tag(:div) do
        concat content_tag(:div, contents_hash[:content])
        concat content_tag(:div, "(#{contents_hash[:explanation]})")
      end
    end
  end

  def quiz_entry_has_two_sides?(contents_hash)
    contents_hash[:content_first].present? || contents_hash[:content_last].present?
  end
end
