class CreatePrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :prompts do |t|
      t.text :raw_prompt
      t.text :sent_role_prompt
      t.string :base_content
      t.string :user_generated_content
      t.string :ai_model
      t.string :uuid
      t.string :type

      t.timestamps
    end
  end
end
