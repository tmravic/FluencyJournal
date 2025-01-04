class CreatePrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :prompts do |t|
      t.references :ai_query, null: true, foreign_key: true
      t.text :raw_prompt
      t.text :sent_role_prompt
      t.string :original_language_prompt
      t.string :learning_language_prompt
      t.string :type
      t.string :ai_model
      t.string :uuid

      t.timestamps
    end
  end
end
