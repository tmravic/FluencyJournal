class CreateAiQueriesFollowupsJoinTable < ActiveRecord::Migration[8.0]
  def change
    create_join_table :ai_queries, :followups do |t|
      t.index :ai_query_id
      t.index :followup_id
      t.index [:ai_query_id, :followup_id], unique: true
    end
  end
end
