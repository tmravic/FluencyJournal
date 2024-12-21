class AddLearningLanguageToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :learning_language, :string
  end
end
