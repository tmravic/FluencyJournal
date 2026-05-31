class FollowupTemplatePromptsController < ApplicationController
  include TemplatePromptConcern

  def index
    @followup_template_prompts = get_template_prompts_scoped_by_user(Current.user)
  end

  def cancel
    @followup_template_prompts = get_template_prompts_scoped_by_user(Current.user)
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
      @followup_template_prompts = get_template_prompts_scoped_by_user(Current.user)

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
      end
    else
      # This can happen for the auto-generated "due notes" template,
      # which is not a real persisted record and cannot be deleted.
      flash.now[:alert] = t('prompt_templates.cannot_delete_system', default: "This template is provided automatically and cannot be deleted.")
    end
  end
end
