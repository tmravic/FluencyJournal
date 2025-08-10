class Note < ApplicationRecord
  belongs_to :user
  has_and_belongs_to_many :followups

  validates :content, presence: true
  validates :next_study_date, presence: true
  validates :category, inclusion: {
    in: ->(_) { Note.categories.keys },
    message: "%{value} is not a valid category"
  }

  enum :category, { vocab: 0, grammar: 1, draft_journal: 2, automatic: 3 }

  scope :next_to_study, -> {
    where(arel_table[:next_study_date].lteq(DateTime.now))
      .order(:next_study_date)
  }

  def previous_note
    all_notes = Current.user&.notes.order(:next_study_date)
    notes_table = Note.arel_table
    all_notes.where(notes_table[:next_study_date].lt(self.next_study_date)).last
  end
end
