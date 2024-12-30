class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :original_language, null: false
      t.string :learning_language, null: false
      t.references :group, null: false, foreign_key: true

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
