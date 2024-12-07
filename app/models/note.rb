class Note < ApplicationRecord
  belongs_to :user
  belongs_to :entry

  validates :content, presence: true

  enum :category, [:vocab, :grammar_rule, :free_note]
  validates :category, presence: true, inclusion: {
    in: category.keys,
    message: "%{value} is not a valid category"
  }
end
