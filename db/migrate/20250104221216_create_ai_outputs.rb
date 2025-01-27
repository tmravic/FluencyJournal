class CreateAiOutputs < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_outputs do |t|
      t.boolean :made_note
      t.string :identifier
      t.text :content
      t.references :ai_query, null: false, foreign_key: true

      t.timestamps
    end
  end
end
