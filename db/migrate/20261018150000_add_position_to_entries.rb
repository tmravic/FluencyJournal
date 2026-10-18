class AddPositionToEntries < ActiveRecord::Migration[8.1]
  def up
    add_column :entries, :position, :integer

    execute <<~SQL.squish
      UPDATE entries
      SET position = mapping.new_position
      FROM (
        SELECT
          id,
          ROW_NUMBER() OVER (PARTITION BY journal_id ORDER BY id) AS new_position
        FROM entries
      ) AS mapping
      WHERE entries.id = mapping.id
    SQL

    change_column_null :entries, :position, false
    add_index :entries, [ :journal_id, :position ], unique: true
  end

  def down
    remove_index :entries, [ :journal_id, :position ]
    remove_column :entries, :position
  end
end
