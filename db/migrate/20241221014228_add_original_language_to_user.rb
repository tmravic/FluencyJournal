class AddOriginalLanguageToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :original_language, :string
  end
end
