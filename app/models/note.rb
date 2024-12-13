class Note < ApplicationRecord
  belongs_to :user
  belongs_to :entry

  validates :content, presence: true

  enum :category, { vocabulary: 0, grammar_rule: 1, free_note: 2 }
end
