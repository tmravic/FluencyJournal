class CreateNotesFollowups < ActiveRecord::Migration[8.0]
  def change
    create_table :notes_followups, id: false do |t|
      t.references :note, null: false, foreign_key: true, index: true
      t.references :followup, null: false, foreign_key: true, index: true

      t.timestamps
    end

    # CREATE TABLE notes_followups (
    #   note_id BIGINT NOT NULL,
    #   followup_id BIGINT NOT NULL,
    #   created_at TIMESTAMP NOT NULL,
    #   updated_at TIMESTAMP NOT NULL,
    #   PRIMARY KEY (note_id, followup_id),
    #   FOREIGN KEY (note_id) REFERENCES notes(id),
    #   FOREIGN KEY (followup_id) REFERENCES followups(id)
    # );

    add_index :notes_followups, [:note_id, :followup_id], unique: true
  end
end
