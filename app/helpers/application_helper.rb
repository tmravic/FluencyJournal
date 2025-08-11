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

  def render_ai_query_change_content(ai_query, identifier, change_keyword, user = nil, html: false)
    contents_hash = create_contents_hash(ai_query, identifier, change_keyword, user)
    # { learning_language:, corrected_sentence:, content_first:, content_last:, content:, explanation: }

    if html
      if has_content_for_ai_output?(contents_hash)
        content_tag(:div) do
          concat content_tag(:div, contents_hash[:content_first])
          concat tag.p("↓")
          concat content_tag(:div, contents_hash[:content_last])
          concat content_tag(:div, "(#{contents_hash[:explanation]})")
        end
      elsif has_content_for_followup?(contents_hash)
        content_tag(:div) do
          concat content_tag(:div, contents_hash[:content])
          concat content_tag(:div, "(#{contents_hash[:explanation]})")
        end
      end

    # for auto-filling notes, html == false
    elsif identifier == "corrected_text"
      "#{contents_hash[:learning_language]}\n↓\n#{contents_hash[:corrected_sentence]}"
    elsif has_content_for_followup?(contents_hash)
      "#{contents_hash[:content]}\n#{contents_hash[:explanation]}"
    else
      "#{contents_hash[:content_first]} → #{contents_hash[:content_last]}\n\n(#{contents_hash[:explanation]})"
    end
  end

  private

  def has_content_for_ai_output?(contents_hash)
    contents_hash[:content_first].present? && contents_hash[:content_last].present? &&
      contents_hash[:explanation].present? && contents_hash[:content].nil?
  end

  def has_content_for_followup?(contents_hash)
    contents_hash[:content_first].nil? && contents_hash[:content_last].nil? &&
      contents_hash[:explanation].present? && contents_hash[:content].present?
  end

  def rendering_followup?(ai_query, identifier, change_keyword)
    ai_query.change_content(identifier, change_keyword).is_a?(String)
  end

  def get_ai_output_correction_variables(ai_query)
    learning_language = ai_query.prompt.learning_language
    corrected_sentence = ai_query.corrected_text

    [ learning_language, corrected_sentence ]
  end

  def get_ai_output_change_variables(ai_query, identifier, change_keyword)
    content_first = ai_query.change_content(identifier, change_keyword).first
    content_last = ai_query.change_content(identifier, change_keyword).last
    explanation = ai_query.change_explanation(change_keyword, identifier, ai_query.abbr(ai_query.user))

    [ content_first, content_last, explanation ]
  end

  def get_followup_variables(ai_query, identifier, change_keyword, user = nil)
    content = ai_query.change_content(identifier, change_keyword)
    explanation = ai_query.change_explanation(change_keyword, identifier, ai_query.abbr(user))

    [ content, explanation ]
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
