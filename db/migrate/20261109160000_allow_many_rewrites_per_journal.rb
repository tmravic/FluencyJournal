class AllowManyRewritesPerJournal < ActiveRecord::Migration[8.1]
  def up
    return unless index_exists?(:journals, :source_journal_id, unique: true, name: "index_journals_on_source_journal_id")

    remove_index :journals, name: "index_journals_on_source_journal_id"
    add_index :journals, :source_journal_id, name: "index_journals_on_source_journal_id"
  end

  def down
    remove_index :journals, name: "index_journals_on_source_journal_id"
    add_index :journals, :source_journal_id, unique: true, name: "index_journals_on_source_journal_id"
  end
end
