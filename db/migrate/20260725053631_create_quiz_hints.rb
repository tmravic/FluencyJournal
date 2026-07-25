class CreateQuizHints < ActiveRecord::Migration[8.0]
  def change
    create_table :quiz_hints do |t|
      t.string :hint_content, null: false
      t.references :quiz, null: false, foreign_key: true
      t.references :entry, null: false, foreign_key: true
      t.references :ai_query, null: false, foreign_key: true
      t.timestamps
    end
  end
end
