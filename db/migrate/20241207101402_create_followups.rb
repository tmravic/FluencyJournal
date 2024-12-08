class CreateFollowups < ActiveRecord::Migration[8.0]
  def change
    create_table :followups do |t|
      t.references :commit, null: false, foreign_key: true

      t.timestamps
    end
  end
end
