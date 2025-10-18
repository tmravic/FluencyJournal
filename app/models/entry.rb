class Entry < ApplicationRecord
  belongs_to :journal
  has_and_belongs_to_many :followups
  has_many :origin_followups, class_name: "Followup", as: :origin, dependent: :nullify

  validates :content, presence: true

  scope :ordered, -> { order(created_at: :asc) }

  def entry_number
    journal.entries.ordered.index(self) + 1
  end
end
