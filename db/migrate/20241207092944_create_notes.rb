class CreateNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :notes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :entry, null: false, foreign_key: true
      t.text :content
      t.integer :category, null: false, default: 0

      t.timestamps
    end
  end
end
