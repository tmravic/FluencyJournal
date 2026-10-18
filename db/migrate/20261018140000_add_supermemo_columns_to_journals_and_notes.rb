class AddSupermemoColumnsToJournalsAndNotes < ActiveRecord::Migration[8.1]
  def up
    add_column :journals, :easiness_factor, :decimal, precision: 4, scale: 2, null: false, default: 2.5
    add_column :journals, :repetitions, :integer, null: false, default: 0
    add_column :notes, :easiness_factor, :decimal, precision: 4, scale: 2, null: false, default: 2.5
    add_column :notes, :repetitions, :integer, null: false, default: 0

    # Rows already reviewed with last_interval * 2.5 should keep multiplying
    # by the ease factor. A repetition count of 2 skips the 1-day and 6-day steps.
    execute <<~SQL.squish
      UPDATE journals
      SET repetitions = 2
      WHERE last_studied_at IS NOT NULL OR last_interval <> 1
    SQL

    execute <<~SQL.squish
      UPDATE notes
      SET repetitions = 2
      WHERE last_interval <> 1
    SQL
  end

  def down
    remove_column :journals, :easiness_factor
    remove_column :journals, :repetitions
    remove_column :notes, :easiness_factor
    remove_column :notes, :repetitions
  end
end
