class Note < ApplicationRecord
  include SchedulesStudy
  include FollowupOrigin

  belongs_to :user
  has_and_belongs_to_many :journals
  has_many :followups, as: :origin, dependent: :destroy

  validates :content, presence: true

  enum :category, { vocab: 0, grammar: 1, draft_journal: 2 }

  scope :by_user, ->(user = Current.user) { where(user_id: user&.id) }

  # The note lists. Each loads what a listed note shows (its followups and
  # journals).
  scope :for_list, -> { includes(:followups, :journals) }
  scope :by_due_date, -> { order(:next_study_date) }
  scope :todays_list, -> { next_to_study.for_list }
  scope :all_list, -> { by_due_date.for_list }
  scope :drafts_list, -> { draft_journal.by_due_date.for_list }

  scope :due_for_study_prompt, -> {
    next_to_study.where.not(category: :draft_journal)
  }

  def followup_owner
    user
  end

  def previous_note(notes)
    previous_in(notes)
  end

  # The note a new note is inserted after in a list. The study date is set
  # first because the position depends on it and it is otherwise unset until
  # validation, which runs after the controller needs the anchor.
  def insertion_anchor_in(notes)
    set_initial_next_study_date
    previous_note(notes)
  end
end
