# frozen_string_literal: true

module TemplatePromptConcern
  def get_template_prompts_scoped_by_user
    FollowupTemplatePrompt.by_user.pluck(:base_content)
  end
end
