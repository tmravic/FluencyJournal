class Commit < ApplicationRecord
  belongs_to :entry
  delegate :user, to: :entry

  validates :content, presence: true
end
