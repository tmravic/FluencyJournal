class CreateCommits < ActiveRecord::Migration[8.0]
  def change
    create_table :commits do |t|
      t.text :content
      t.references :entry, null: false, foreign_key: true

      t.timestamps
    end
  end
end
