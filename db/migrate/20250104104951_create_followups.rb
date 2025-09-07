class CreateFollowups < ActiveRecord::Migration[8.0]
  def change
    create_table :followups do |t|
      t.references :origin, polymorphic: true, index: true
      t.string :source_tag
      t.references :prompt, null: false, foreign_key: true

      t.timestamps
    end
  end
end
