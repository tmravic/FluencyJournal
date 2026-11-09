class AddSourceJournalToJournals < ActiveRecord::Migration[8.1]
  def change
    add_reference :journals, :source_journal, foreign_key: { to_table: :journals }
  end
end
