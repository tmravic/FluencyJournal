class CreateAiOutputsFollowupsJoinTable < ActiveRecord::Migration[8.0]
  def change
    create_join_table :ai_outputs, :followups, id: false do |t|
      t.index :ai_output_id
      t.index :followup_id
      t.index [ :ai_output_id, :followup_id ], unique: true
    end
  end
end
