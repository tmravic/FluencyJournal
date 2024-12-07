class Entry < ApplicationRecord
  belongs_to :user
  has_many :commits, dependent: :destroy

  validates :content, presence: true
end
