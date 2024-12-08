class Commit < ApplicationRecord
  belongs_to :entry
  delegate :user, to: :entry
  has_many :prompts
  has_many :ai_queries

  validates :content, presence: true
end
