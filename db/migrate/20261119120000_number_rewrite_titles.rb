class NumberRewriteTitles < ActiveRecord::Migration[8.1]
  def up
    Journal.reset_column_information
    parent_ids = Journal.where.not(source_journal_id: nil).distinct.pluck(:source_journal_id)

    Journal.where(id: parent_ids).find_each do |parent|
      number = 1
      parent.rewrites.order(:id).each do |rewrite|
        title = nil
        loop do
          title = Journal.rewrite_title(parent.title, number)
          number += 1
          break unless Journal.where(user_id: parent.user_id, title: title).where.not(id: rewrite.id).exists?
        end
        rewrite.update_columns(title: title) if rewrite.title != title
      end
    end
  end

  def down
    execute <<~SQL.squish
      UPDATE journals AS rewrites
      SET title = parents.title
      FROM journals AS parents
      WHERE rewrites.source_journal_id = parents.id
    SQL
  end
end
