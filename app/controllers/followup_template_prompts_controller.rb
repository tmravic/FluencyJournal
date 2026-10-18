class FollowupTemplatePromptsController < ApplicationController
  include TemplatePromptConcern

  def index
    @followup_template_prompts = deletable_template_options(Current.user)
  end

  def cancel
    @followup_template_prompts = get_template_prompts_scoped_by_user(Current.user, include_due_notes_template: false)
    @source_tag = params.dig(:source_tag)

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = notice }
    end
  end

  def destroy_selected
    prompt = FollowupTemplatePrompt.by_user(Current.user).find_by(id: params[:prompt_template])

    if prompt&.destroy
      notice = t('prompt_templates.deleted')
      @followup_template_prompts = get_template_prompts_scoped_by_user(Current.user, include_due_notes_template: false)

      respond_to do |format|
        format.html { redirect_to followup_template_prompts_path, status: :see_other, notice: notice }
        format.turbo_stream { flash.now[:notice] = notice }
      end
    else
      respond_to do |format|
        format.html { redirect_to followup_template_prompts_path, status: :see_other, alert: t("prompt_templates.no_selection") }
        format.turbo_stream { head :unprocessable_entity }
      end
    end
  end
end
