# A retried quiz answer used to be added as a second row for the same
# question, which shifted every answer after it when the grader's prompt was
# built. Keep the newest answer per (quiz, question), then make a second one
# impossible.
#
# The cleanup deletes rows and is not undone by rolling back: take a database
# backup before running it. Rolling back only removes the index.
class AddUniqueIndexToQuizAnswers < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      DELETE FROM quiz_answers
      WHERE id IN (
        SELECT id FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY quiz_id, ai_output_id
                   ORDER BY created_at DESC, id DESC
                 ) AS position
          FROM quiz_answers
        ) ranked
        WHERE ranked.position > 1
      )
    SQL

    add_index :quiz_answers, [ :quiz_id, :ai_output_id ], unique: true
  end

  def down
    remove_index :quiz_answers, [ :quiz_id, :ai_output_id ]
  end
end
