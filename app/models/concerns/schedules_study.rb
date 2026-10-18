module SchedulesStudy
  extend ActiveSupport::Concern

  # Mark studied is a correct recall. Quality 4 leaves the ease factor unchanged.
  STUDIED_QUALITY = 4

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
end
