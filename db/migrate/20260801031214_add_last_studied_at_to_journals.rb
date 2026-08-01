class AddLastStudiedAtToJournals < ActiveRecord::Migration[8.0]
  def change
    add_column :journals, :last_studied_at, :datetime
    add_index :journals, :last_studied_at
  end
end
