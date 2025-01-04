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

  def render_ai_query_change_content(ai_query, index, html: false)
    content_first = ai_query.change_content(index).first
    content_last = ai_query.change_content(index).last
    explanation = ai_query.change_explanation(index, ai_query.abbr(ai_query.user))

    if html
      content_tag(:div) do
        concat content_tag(:div, content_first)
        concat tag.p("↓")
        concat content_tag(:div, content_last)
        concat content_tag(:div, "(#{explanation})")
      end
    else
      "#{content_first} → #{content_last}\n\n(#{explanation})"
    end
  end
end
