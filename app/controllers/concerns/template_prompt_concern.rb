# frozen_string_literal: true

module TemplatePromptConcern
  def get_template_prompts_scoped_by_user(user, due_notes_dropdown: :full, include_due_notes_template: true)
    db_templates = FollowupTemplatePrompt.by_user(user).pluck(:base_content)

    if include_due_notes_template
      due_notes_template = build_due_notes_template(user, format: due_notes_dropdown)
      if due_notes_template.present?
        return [ due_notes_template ] + db_templates
      end
    end

    db_templates
  end

  # Delete form options. The followup picker still uses the text, because that
  # text is copied into the question field.
  def deletable_template_options(user)
    FollowupTemplatePrompt.by_user(user).pluck(:base_content, :id)
  end

  def expand_due_notes_prompt(base_content, user)
    return unless due_notes_prompt_selected?(base_content)

    build_due_notes_template(user, format: :full)
  end

  private

  def due_notes_prompt_selected?(base_content)
    return false if base_content.blank?

    normalized = base_content.strip
    normalized == due_notes_short_label ||
      normalized.start_with?(due_notes_prefix)
  end

  def due_notes_short_label
    I18n.t("prompt_templates.due_notes_short")
  end

  def due_notes_prefix
    I18n.t(
      "prompt_templates.due_notes_prefix",
      default: "Create example sentences or explanations for these due notes: "
    )
  end

  def build_due_notes_template(user, format: :full)
    contents = Note.by_user(user).due_for_study_prompt.pluck(:content).compact_blank.uniq
    return nil if contents.empty?

    return due_notes_short_label if format == :short

    list = contents.join(", ")
    if list.length > 400
      list = list[0..397] + "..."
    end

    "#{due_notes_prefix}#{list}"
  end
end
