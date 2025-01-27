class CreateFollowups < ActiveRecord::Migration[8.0]
  def change
    create_table :followups do |t|
      t.string :followup_origin_class
      t.integer :followup_origin_id
      t.string :source_tag
      t.references :prompt, null: false, foreign_key: true

      t.timestamps
    end
  end
end
