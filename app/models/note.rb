class Note < ApplicationRecord
  belongs_to :user
  belongs_to :entry, optional: true

  validates :content, presence: true
  validates :category, inclusion: {
    in: ->(_) { Note.categories.keys },
    message: "%{value} is not a valid category"
  }

  enum :category, { vocab: 0, grammar: 1, free: 2, automatic: 3 }
end
