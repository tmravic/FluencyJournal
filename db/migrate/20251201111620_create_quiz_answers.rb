class CreateQuizAnswers < ActiveRecord::Migration[8.0]
  def change
    create_table :quiz_answers do |t|
      t.text :user_response
      t.text :feedback
      t.references :quiz, null: false, foreign_key: true
      t.references :ai_output, null: false, foreign_key: true
      t.timestamps
    end
  end
end
