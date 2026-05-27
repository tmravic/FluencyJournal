class CreateJournalFollowups < ActiveRecord::Migration[8.0]
  def change
    create_table :journal_followups do |t|
      t.references :journal, null: false, foreign_key: true

      t.timestamps
    end
  end
end
