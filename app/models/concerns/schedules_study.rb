module SchedulesStudy
  extend ActiveSupport::Concern

  # Mark studied is a correct recall. Quality 4 leaves the ease factor unchanged.
  STUDIED_QUALITY = 4

  included do
    validates :next_study_date, presence: true
    validates :last_interval, numericality: true
    validates :easiness_factor, numericality: true
    validates :repetitions, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    before_validation :set_initial_next_study_date, on: :create

    scope :next_to_study, -> {
      where(next_study_date: ..Time.current).order(:next_study_date)
    }
  end

  def set_initial_next_study_date
    self.next_study_date ||= Time.current
  end

  def schedule_after_study
    interval, ease, repetition_count = SuperMemo::SM2.i_and_ef_and_n(
      repetitions,
      STUDIED_QUALITY,
      last_interval.to_f,
      easiness_factor.to_f
    )

    self.repetitions = repetition_count
    self.easiness_factor = ease
    self.last_interval = interval
    self.next_study_date = interval.to_d.days.from_now
  end

  # Records a successful study session and saves. Returns what save
  # returns.
  def mark_studied
    schedule_after_study
    save
  end

  # The record in +records+ due just before this one, or nil.
  def previous_in(records)
    return nil if records.nil? || next_study_date.nil?

    records.where(next_study_date: ...next_study_date).order(:next_study_date).last
  end
end
