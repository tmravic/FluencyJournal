class Note < ApplicationRecord
  include SchedulesStudy

  belongs_to :user
  has_and_belongs_to_many :journals
  has_and_belongs_to_many :followups
  has_many :origin_followups, class_name: "Followup", as: :origin, dependent: :nullify

  validates :content, presence: true
  validates :next_study_date, presence: true
  validates :last_interval, numericality: true
  validates :easiness_factor, numericality: true
  validates :repetitions, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :set_initial_next_study_date, on: :create

  def set_initial_next_study_date
    self.next_study_date ||= Time.current
  end

  enum :category, { vocab: 0, grammar: 1, draft_journal: 2 }

  scope :by_user, ->(user = Current.user) { where(user_id: user&.id) }

  scope :next_to_study, -> {
    where(next_study_date: ..Time.current).order(:next_study_date)
  }

  scope :due_for_study_prompt, -> {
    next_to_study.where.not(category: :draft_journal)
  }

  def previous_note(notes)
    return nil if notes.nil? || next_study_date.nil?

    notes.where(next_study_date: ...next_study_date).order(:next_study_date).last
  end
end
