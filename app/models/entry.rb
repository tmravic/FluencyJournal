class Entry < ApplicationRecord
  belongs_to :user
  has_many :commits, dependent: :destroy
  has_many :notes, dependent: :destroy

  validates :content, presence: true
end
