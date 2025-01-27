class CreateFollowupsNotesJoinTable < ActiveRecord::Migration[8.0]
  def change
    create_join_table :followups, :notes do |t|
      t.index :note_id
      t.index :followup_id
      t.index [:note_id, :followup_id], unique: true
    end
  end
end
