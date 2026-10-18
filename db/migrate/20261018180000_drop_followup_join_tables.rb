class DropFollowupJoinTables < ActiveRecord::Migration[8.1]
  def up
    # A followup whose origin was never saved still has the parent id on a
    # join row. Copy that id onto origin before the join tables go away.
    # The answer query is already followups.prompt_id, so its join is not copied.
    backfill_origin("entries_followups", "entry_id", "Entry")
    backfill_origin("followups_notes", "note_id", "Note")
    backfill_origin("ai_outputs_followups", "ai_output_id", "AiOutput")

    drop_table :entries_followups
    drop_table :followups_notes
    drop_table :ai_outputs_followups
    drop_table :ai_queries_followups
  end

  def down
    create_join_table :entries, :followups do |t|
      t.index :entry_id
      t.index :followup_id
      t.index [ :entry_id, :followup_id ], unique: true
    end

    create_join_table :followups, :notes do |t|
      t.index :note_id
      t.index :followup_id
      t.index [ :note_id, :followup_id ], unique: true
    end

    create_join_table :ai_outputs, :followups, id: false do |t|
      t.index :ai_output_id
      t.index :followup_id
      t.index [ :ai_output_id, :followup_id ], unique: true
    end

    create_join_table :ai_queries, :followups do |t|
      t.index :ai_query_id
      t.index :followup_id
      t.index [ :ai_query_id, :followup_id ], unique: true
    end
  end

  private

  def backfill_origin(join_table, foreign_key, origin_type)
    quoted_type = connection.quote(origin_type)

    execute <<~SQL.squish
      UPDATE followups
      SET origin_type = #{quoted_type}, origin_id = chosen.#{foreign_key}
      FROM (
        SELECT DISTINCT ON (followup_id) followup_id, #{foreign_key}
        FROM #{join_table}
        ORDER BY followup_id, #{foreign_key}
      ) chosen
      WHERE followups.id = chosen.followup_id
        AND followups.origin_id IS NULL
    SQL
  end
end
