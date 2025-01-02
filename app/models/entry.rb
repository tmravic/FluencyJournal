class Entry < ApplicationRecord
  belongs_to :journal

  validates :content, presence: true

  scope :ordered, -> { order(created_at: :asc) }

  def entry_number
    journal.entries.ordered.index(self) + 1
  end
end
