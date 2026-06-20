class CreateJournalsNotesJoinTable < ActiveRecord::Migration[8.0]
  def up
    if column_exists?(:notes, :journal_id)
      remove_foreign_key :notes, :journals, column: :journal_id, if_exists: true
      remove_column :notes, :journal_id
    end

    return if table_exists?(:journals_notes)

    create_join_table :journals, :notes do |t|
      t.index :journal_id
      t.index :note_id
      t.index [ :journal_id, :note_id ], unique: true
    end
  end

  def down
    drop_join_table :journals, :notes if table_exists?(:journals_notes)
  end
end