class CreateEntriesFollowups < ActiveRecord::Migration[8.0]
  def change
    create_table :entries_followups, id: false do |t|
      t.references :entry, null: false, foreign_key: true, index: true
      t.references :followup, null: false, foreign_key: true, index: true

      t.timestamps
    end

    add_index :entries_followups, [:entry_id, :followup_id], unique: true
  end
end
