class Commit < ApplicationRecord
  belongs_to :journal

  validates :content, presence: true

  scope :ordered, -> { order(created_at: :asc) }

  def commit_number
    journal.commits.ordered.index(self) + 1
  end
end
