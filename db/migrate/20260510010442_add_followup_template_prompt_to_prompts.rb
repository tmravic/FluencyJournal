class AddFollowupTemplatePromptToPrompts < ActiveRecord::Migration[8.0]
  def change
    add_reference :prompts, :followup_template_prompt, foreign_key: true, null: true, index: true
  end
end
