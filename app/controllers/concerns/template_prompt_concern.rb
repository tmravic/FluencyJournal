# frozen_string_literal: true

module TemplatePromptConcern
  def get_template_prompts_scoped_by_user(user)
    db_templates = FollowupTemplatePrompt.by_user(user).pluck(:base_content)

    due_notes_template = build_due_notes_template(user)
    if due_notes_template.present?
      [due_notes_template] + db_templates
    else
      db_templates
    end
  end

  private

  def build_due_notes_template(user)
    contents = Note.by_user(user).next_to_study.pluck(:content).compact_blank.uniq
    return nil if contents.empty?

    prefix = I18n.t("prompt_templates.due_notes_prefix", default: "Create example sentences or explanations for these due notes: ")
    list = contents.join(", ")

    # Truncate very long lists to keep the dropdown usable
    if list.length > 400
      list = list[0..397] + "..."
    end

    "#{prefix}#{list}"
  end
end
