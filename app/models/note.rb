class Note < ApplicationRecord
  include SchedulesStudy
  include FollowupOrigin

  belongs_to :user
  has_and_belongs_to_many :journals
  has_many :followups, as: :origin, dependent: :destroy

  validates :content, presence: true

  enum :category, { vocab: 0, grammar: 1, draft_journal: 2 }

  scope :by_user, ->(user = Current.user) { where(user_id: user&.id) }

  scope :due_for_study_prompt, -> {
    next_to_study.where.not(category: :draft_journal)
  }

  def previous_note(notes)
    previous_in(notes)
  end
end
