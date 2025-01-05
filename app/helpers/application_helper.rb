module ApplicationHelper
  def render_turbo_stream_flash_messages
    turbo_stream.prepend "flash", partial: "layouts/flash"
  end

  def form_error_notification(object)
    if object.errors.any?
      tag.div class: "error-message" do
        object.errors.full_messages.to_sentence.capitalize
      end
    end
  end

  def render_ai_query_change_content(ai_query, identifier, html: false)
    if identifier == 'corrected_text'
      learning_language = ai_query.prompt.parsed_prompt.last[18..]
      corrected_sentence = ai_query.corrected_text
    else
      content_first = ai_query.change_content(identifier).first
      content_last = ai_query.change_content(identifier).last
      explanation = ai_query.change_explanation(identifier, ai_query.abbr(ai_query.user))
    end

    if html
      content_tag(:div) do
        concat content_tag(:div, content_first)
        concat tag.p("↓")
        concat content_tag(:div, content_last)
        concat content_tag(:div, "(#{explanation})")
      end
    elsif identifier == 'corrected_text'
      "#{learning_language}\n↓\n#{corrected_sentence}"
    else
      "#{content_first} → #{content_last}\n\n(#{explanation})"
    end
  end
end
