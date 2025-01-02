class CreateAiQueries < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_queries do |t|
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :total_tokens
      t.string :type
      t.text :raw_response
      t.boolean :made_note
      t.references :entry, foreign_key: true
      t.references :followup, foreign_key: true

      t.timestamps
    end
  end
end
