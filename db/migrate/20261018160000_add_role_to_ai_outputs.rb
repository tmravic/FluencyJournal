class AddRoleToAiOutputs < ActiveRecord::Migration[8.1]
  def up
    add_column :ai_outputs, :role, :string, null: false, default: "line"

    execute <<~SQL.squish
      UPDATE ai_outputs
      SET role = identifier
      WHERE identifier IN ('corrected_text', 'assessment')
    SQL
  end

  def down
    remove_column :ai_outputs, :role
  end
end