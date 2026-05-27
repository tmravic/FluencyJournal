class JournalFollowup < ApplicationRecord
  belongs_to :journal
  has_many :followups, as: :origin, dependent: :destroy

  def content
    journal&.full_journal&.join("\n\n")
  end
end
