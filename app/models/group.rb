class Group < ApplicationRecord
  has_many :users
  has_many :journals

  validates :name, presence: true
  # validate :member_count, numericality
end
