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
    prompt = FollowupTemplatePrompt.find_by(base_content: (params.dig(:prompt_template)))
    if prompt&.destroy
      prompt.destroy
      notice = t('prompt_templates.deleted')
      @followup_template_prompts = get_template_prompts_scoped_by_user(Current.user)

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
      end

    else
      flash.now[:alert] = t('prompt_templates.no_selection')
    end
  end
end
