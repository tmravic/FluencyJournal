class CreatePrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :prompts do |t|
      t.references :ai_query, null: false, foreign_key: true
      t.references :commit, null: false, foreign_key: true
      t.references :followup, null: false, foreign_key: true
      t.text :raw_prompt
      t.string :type
      t.string :ai_model
      t.string :uuid

      t.timestamps
    end
  end
end
