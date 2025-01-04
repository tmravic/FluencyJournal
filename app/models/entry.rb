class Entry < ApplicationRecord
  belongs_to :journal
  has_many :entries_followups
  has_many :followups, through: :entries_followups

  validates :content, presence: true

  scope :ordered, -> { order(created_at: :asc) }

  def entry_number
    journal.entries.ordered.index(self) + 1
  end
end
