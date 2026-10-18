class RetireQuizHintPrompts < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE prompts SET type = 'Prompt' WHERE type = 'QuizHintPrompt'
    SQL
  end

  def down
  end
end
