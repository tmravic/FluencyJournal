class Group < ApplicationRecord
  has_many :users
  has_many :entries

  validates :name, presence: true
  # validate :member_count, numericality
end
