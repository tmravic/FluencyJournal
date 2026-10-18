require "rails_helper"

RSpec.describe SchedulesStudy do
  def create_user
    group = Group.create!(name: "Schedule group #{SecureRandom.hex(4)}")
    User.create!(
      email_address: "schedule-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
  end

  def study(record)
    record.schedule_after_study
    record.save!
    record.reload
  end

  it "gives a new journal the SM-2 intervals of 1 day, then 6, then 15" do
    user = create_user
    journal = Journal.create!(title: "New", user: user, group: user.group, last_interval: 1)

    study(journal)
    expect(journal.repetitions).to eq(1)
    expect(journal.last_interval).to eq(1)
    expect(journal.easiness_factor).to eq(2.5)
    expect(journal.next_study_date).to be_within(1.minute).of(1.day.from_now)

    study(journal)
    expect(journal.repetitions).to eq(2)
    expect(journal.last_interval).to eq(6)
    expect(journal.next_study_date).to be_within(1.minute).of(6.days.from_now)

    study(journal)
    expect(journal.repetitions).to eq(3)
    expect(journal.last_interval).to eq(15)
    expect(journal.easiness_factor).to eq(2.5)
    expect(journal.next_study_date).to be_within(1.minute).of(15.days.from_now)
  end

  it "keeps multiplying an already reviewed note by its ease factor" do
    user = create_user
    note = user.notes.create!(
      content: "Reviewed",
      last_interval: 2.5,
      repetitions: 2,
      easiness_factor: 2.5
    )

    study(note)

    expect(note.repetitions).to eq(3)
    expect(note.last_interval).to eq(6.25)
    expect(note.easiness_factor).to eq(2.5)
    expect(note.next_study_date).to be_within(1.minute).of(6.25.days.from_now)
  end

  it "sends a missed recall back to a one-day interval" do
    user = create_user
    journal = Journal.create!(
      title: "Lapse",
      user: user,
      group: user.group,
      last_interval: 15,
      repetitions: 3,
      easiness_factor: 2.5
    )

    interval, ease, repetition_count = SuperMemo::SM2.i_and_ef_and_n(
      journal.repetitions,
      2,
      journal.last_interval.to_f,
      journal.easiness_factor.to_f
    )

    expect(interval).to eq(1)
    expect(ease).to eq(2.5)
    expect(repetition_count).to eq(1)
    expect(SuperMemo::SM2.should_repeat_today(2)).to be(true)
  end
end
