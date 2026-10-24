module ApplicationHelper
  def set_ai_query_when_job_finishes(ai_query_id, message)
    AiQuery.find(ai_query_id) if ai_query_id.present? && ai_query_id != message
  end

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

  def display_next_review_time(object)
    if object.next_study_date.present?
      # The browser decides today, yesterday, and tomorrow. A date further
      # away stays a calendar day in that same zone.
      local_relative_time(object.next_study_date, type: "weekday-or-date")
    else
      t("note.no_date_set")
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
    elsif contents_hash[:content_first].present? || contents_hash[:content_last].present?
      "#{contents_hash[:content_first]} → #{contents_hash[:content_last]}\n\n(#{contents_hash[:explanation]})"
    end
  end

  # The "← Back to …" link at the top of the form and detail pages.
  def back_link(text, path)
    link_to sanitize("&larr; #{text}"), path
  end

  # [label, model id] pairs for the model select, from Prompt::MODELS.
  def ai_model_options
    Prompt::MODEL_LABEL_KEYS.map { |model, label_key| [ t(label_key), model ] }
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
    learning_language = ai_query.prompt.user_generated_content
    corrected_sentence = ai_query.corrected_text

    [ learning_language, corrected_sentence ]
  end

  def get_ai_output_change_variables(ai_query, identifier, change_keyword)
    user = ai_query.user || Current.user || @user
    content_first, content_last = ai_query.change_sides(identifier, change_keyword)
    explanation = ai_query.change_explanation(change_keyword, identifier, Prompt.explanation_language_code(user)) if user

    [ content_first, content_last, explanation ]
  end

  def get_followup_variables(ai_query, identifier, change_keyword, user = nil)
    content = ai_query.change_content(identifier, change_keyword)
    reader = user || ai_query.user
    explanation = ai_query.change_explanation(change_keyword, identifier, Prompt.explanation_language_code(reader)) if reader

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

  def generate_original_and_learning_language
    # e.g. En → Ja
    original = language_code(Current.user.original_language)
    learning = language_code(Current.user.learning_language)
    "#{original} → #{learning}"
  end

  # Display form ("En", "Ja") of Prompt::LANGUAGE_ABBREVIATIONS. Languages
  # without an entry fall back to their first two letters ("Thai" => "Th").
  def language_code(language)
    Prompt.language_code(language, default: language.to_s[0, 2]).capitalize
  end
end
