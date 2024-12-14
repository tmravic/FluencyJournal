class Group < ApplicationRecord
  has_many :users
  has_many :entries

  validates :name, presence: true
end
