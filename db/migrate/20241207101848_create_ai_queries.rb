class CreateAiQueries < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_queries do |t|
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :total_tokens
      t.string :type
      t.text :raw_response
      t.integer :change_count
      t.jsonb :made_note, default: {}, null: false # Use jsonb for storing a hash
      t.references :journal, foreign_key: true

      t.timestamps
    end
  end
end
