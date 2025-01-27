class CreateEntriesFollowupsJoinTable < ActiveRecord::Migration[8.0]
  def change
    create_join_table :entries, :followups do |t|
      t.index :entry_id
      t.index :followup_id
      t.index [:entry_id, :followup_id], unique: true
    end
  end
end
#                        Table "public.entries_followups"
#    Column    |              Type              | Collation | Nullable | Default
# -------------+--------------------------------+-----------+----------+---------
#  entry_id    | bigint                         |           | not null |
#  followup_id | bigint                         |           | not null |
#  created_at  | timestamp(6) without time zone |           | not null |
#  updated_at  | timestamp(6) without time zone |           | not null |
# Indexes:
#     "index_entries_followups_on_entry_id" btree (entry_id)
#     "index_entries_followups_on_entry_id_and_followup_id" UNIQUE, btree (entry_id, followup_id)
#     "index_entries_followups_on_followup_id" btree (followup_id)
# Foreign-key constraints:
#     "fk_rails_30c0cd9e0b" FOREIGN KEY (followup_id) REFERENCES followups(id)
#     "fk_rails_9adddfd007" FOREIGN KEY (entry_id) REFERENCES entries(id)
