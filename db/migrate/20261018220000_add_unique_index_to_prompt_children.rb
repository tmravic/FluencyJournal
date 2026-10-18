class AddUniqueIndexToPromptChildren < ActiveRecord::Migration[8.1]
  def change
    remove_index :ai_queries, :prompt_id, name: "index_ai_queries_on_prompt_id"
    add_index :ai_queries, :prompt_id, unique: true, name: "index_ai_queries_on_prompt_id"

    remove_index :followups, :prompt_id, name: "index_followups_on_prompt_id"
    add_index :followups, :prompt_id, unique: true, name: "index_followups_on_prompt_id"
  end
end
