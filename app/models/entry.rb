class Entry < ApplicationRecord
  include FollowupOrigin

  belongs_to :journal
  has_many :followups, as: :origin, dependent: :nullify
  has_many :quiz_hints, dependent: :destroy

  # A new line should not rewrite the timestamps of the other lines.
  acts_as_list scope: :journal, touch_on_update: false

  # Longer text is refused when it is typed or pasted in. A row that is
  # already longer stays readable and editable: the limit is only checked
  # when the content itself changes.
  MAX_CONTENT_LENGTH = 5_000

  validates :content, presence: true
  validates :content, length: { maximum: MAX_CONTENT_LENGTH }, if: :will_save_change_to_content?

  scope :ordered, -> { order(:position) }

  def entry_number
    position
  end

  def followup_journal
    journal
  end

  def followup_owner
    journal.user
  end
end
