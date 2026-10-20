class FollowupTemplatePromptsController < ApplicationController
  include TemplatePromptConcern

  def index
    @followup_template_prompts = deletable_template_options(Current.user)
  end

  def cancel
    load_template_options
    @source_tag = params[:source_tag]

    respond_to do |format|
      format.turbo_stream
    end
  end

  def destroy_selected
    prompt = FollowupTemplatePrompt.by_user(Current.user).find_by(id: params[:prompt_template])

    if prompt&.destroy
      notice = t('prompt_templates.deleted')
      load_template_options

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

  private

  # The selectable templates, without the generated due-notes entry.
  def load_template_options
    @followup_template_prompts = get_template_prompts_scoped_by_user(Current.user, include_due_notes_template: false)
  end
end
