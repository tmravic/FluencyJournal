class CreateNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :notes do |t|
      t.references :user, null: false, foreign_key: true
      t.text :content
      t.integer :category, null: false, default: 0
      t.decimal :last_interval, null: false, default: 1, precision: 10, scale: 2
      t.datetime :next_study_date

      t.timestamps
    end
  end
end
