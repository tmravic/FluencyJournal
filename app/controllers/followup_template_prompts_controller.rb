class FollowupTemplatePromptsController < ApplicationController
  include TemplatePromptConcern

  def index
    @followup_template_prompts = get_template_prompts_scoped_by_user(Current.user, include_due_notes_template: false)
  end

  def cancel
    @followup_template_prompts = get_template_prompts_scoped_by_user(Current.user, include_due_notes_template: false)
    @source_tag = params.dig(:source_tag)

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = notice }
    end
  end

  def destroy_selected
    selected = params.dig(:prompt_template).to_s.strip
    prompt = FollowupTemplatePrompt.find_by(base_content: selected)

    if prompt&.destroy
      notice = t('prompt_templates.deleted')
      @followup_template_prompts = get_template_prompts_scoped_by_user(Current.user, include_due_notes_template: false)

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
      end
    else
      flash.now[:alert] = t("prompt_templates.no_selection")
    end
  end
end
