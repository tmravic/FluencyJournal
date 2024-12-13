class Entry < ApplicationRecord
  belongs_to :user
  has_many :commits, dependent: :destroy
  has_many :notes, dependent: :destroy

  validates :title, presence: true
  validates :content, presence: true
end