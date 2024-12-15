class AddGroupReferenceToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :group, null: false, foreign_key: true
  end
end
