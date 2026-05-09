class AddMeaningAndExtrasToNote < ActiveRecord::Migration[8.0]
  def change
    add_column :notes, :meaning, :text
    add_column :notes, :extras, :text
  end
end
