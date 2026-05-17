class AddUserToFollowupTemplatePrompt < ActiveRecord::Migration[8.0]
  def change
    add_reference :followup_template_prompts, :user, foreign_key: true, null: true, index: true
  end
end
