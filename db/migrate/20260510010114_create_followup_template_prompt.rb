class CreateFollowupTemplatePrompt < ActiveRecord::Migration[8.0]
  def change
    create_table :followup_template_prompts do |t|
      t.string :base_content

      t.timestamps
    end
  end
end
