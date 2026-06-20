class CreateJournalsNotesJoinTable < ActiveRecord::Migration[8.0]
  def change
    remove_reference :notes, :journal, foreign_key: true, if_exists: true

    create_join_table :journals, :notes do |t|
      t.index :journal_id
      t.index :note_id
      t.index [ :journal_id, :note_id ], unique: true
    end
  end
end