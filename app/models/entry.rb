class Entry < ApplicationRecord
  belongs_to :journal
  has_and_belongs_to_many :followups
  has_many :origin_followups, class_name: "Followup", as: :origin, dependent: :nullify
  has_many :quiz_hints, dependent: :destroy

  # A new line should not rewrite the timestamps of the other lines.
  acts_as_list scope: :journal, touch_on_update: false

  validates :content, presence: true

  scope :ordered, -> { order(:position) }

  def entry_number
    position
  end
end
