class CreateJournals < ActiveRecord::Migration[8.0]
  def change
    create_table :journals do |t|
      t.string :title
      t.references :user, null: false, foreign_key: true
      t.references :group, null: false, foreign_key: true
      t.decimal :last_interval, null: false, default: 1, precision: 10, scale: 2
      t.datetime :next_study_date

      t.timestamps
    end
  end
end
