class Commit < ApplicationRecord
  belongs_to :entry

  validates :content, presence: true

  scope :ordered, -> { order(created_at: :asc) }

  def commit_number
    entry.commits.ordered.index(self) + 1
  end
end
