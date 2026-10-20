class JournalFollowup < ApplicationRecord
  belongs_to :journal
  has_many :followups, as: :origin, dependent: :destroy

  def content
    journal.full_text
  end
end
