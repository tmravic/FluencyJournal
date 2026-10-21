# frozen_string_literal: true

module TemplatePromptConcern
  # Everything here is a controller helper, not an action, so it is all
  # private: public methods in a controller module become routable actions.
  private

  # The followup template dropdown: the due-notes template (when any
  # notes are due and it is wanted) followed by the user's saved templates.
  def get_template_prompts_scoped_by_user(user, due_notes_dropdown: :full, include_due_notes_template: true)
    db_templates = FollowupTemplatePrompt.by_user(user).pluck(:base_content)
    return db_templates unless include_due_notes_template

    due_notes_template = DueNotesTemplate.new(user).text(due_notes_dropdown)
    due_notes_template.present? ? [ due_notes_template ] + db_templates : db_templates
  end

  # Delete form options. The followup picker still uses the text, because that
  # text is copied into the question field.
  def deletable_template_options(user)
    FollowupTemplatePrompt.by_user(user).pluck(:base_content, :id)
  end

  # The full due-notes prompt when +base_content+ picked that template,
  # else nil.
  def expand_due_notes_prompt(base_content, user)
    template = DueNotesTemplate.new(user)
    return unless template.selected_by?(base_content)

    template.text(:full)
  end
end
