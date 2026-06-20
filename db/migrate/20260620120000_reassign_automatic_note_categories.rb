class ReassignAutomaticNoteCategories < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE notes SET category = 0 WHERE category = 3"
  end

  def down
    # category 3 (automatic) is no longer a valid enum value
  end
end