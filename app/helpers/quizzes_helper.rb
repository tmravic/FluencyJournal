module QuizzesHelper
  def build_quiz_answer(quiz, ai_output)
    quiz.quiz_answers.build(ai_output: ai_output)
  end

  def set_assessment_output(ai_query)
    ai_query.find_ai_output_by_identifier("assessment") if ai_query
  end

  def render_ai_query_entry_content(ai_query, identifier, entry_keyword, user, quiz, html: false)
    output = ai_query.find_ai_output_by_identifier(identifier)
    return "" unless output # Safety check

    if html
      # Split the pre-assembled content into lines, removing empty ones
      lines = output.content.split("\n").reject(&:blank?)

      content_tag(:div) do
        lines.each do |line|
          if line.start_with?("(") && line.end_with?(")")
            # Explanation in parentheses
            concat content_tag(:div, line)
          elsif line == "↓"
            # Down arrow as paragraph
            concat tag.p(line)
          else
            # Original/graded or other content as div
            concat content_tag(:div, line)
          end
        end
      end
    else
      # Plain text fallback (e.g., for non-HTML contexts)
      output.content
    end
  end
end