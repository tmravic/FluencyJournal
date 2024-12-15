class Commit < ApplicationRecord
  belongs_to :entry

  validates :content, presence: true

  scope :ordered, -> { order(created_at: :asc) }
end
