class Entry < ApplicationRecord
  include FollowupOrigin

  belongs_to :journal
  has_many :followups, as: :origin, dependent: :nullify
  has_many :quiz_hints, dependent: :destroy

  # A new line should not rewrite the timestamps of the other lines.
  acts_as_list scope: :journal, touch_on_update: false

  validates :content, presence: true

  scope :ordered, -> { order(:position) }

  def entry_number
    position
  end

  def followup_journal
    journal
  end
end
