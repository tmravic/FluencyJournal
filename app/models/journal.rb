class Journal < ApplicationRecord
  include SchedulesStudy

  belongs_to :user
  belongs_to :group
  has_many :entries, -> { order(:position) }, dependent: :destroy
  has_and_belongs_to_many :notes
  has_many :ai_queries, dependent: :destroy
  has_many :quizzes, dependent: :destroy
  has_many :journal_followups, dependent: :destroy

  validates :title, presence: true

  scope :ordered, -> { order(:next_study_date) }
  scope :alphabetical, -> { reorder(:title) }
  # The journals due for study when due_only, otherwise all of them.
  scope :due_or_all, ->(due_only) { due_only ? next_to_study : all }
  # scope :personal, -> {  }
  # scope :private, -> {  }
  # scope :public, -> {  }
  # scope :shared (either private or publish, not personal), -> {  }

  # Preloads the query history shown on the journal page (quizzes, followups).
  scope :with_query_history, -> {
    includes(ai_queries: [ :quizzes, :graded_quizzes, { prompt: :followup } ])
  }

  scope :finished_today, -> {
    where(last_studied_at: 24.hours.ago..).order(:last_studied_at)
  }

  # The signed stream name comes from the array this lambda returns:
  # [journal.group, "journals"].
  broadcasts_to ->(journal) { [ journal.group, "journals" ] }, inserts_by: :append

  def entry_at(number)
    entries.find_by(position: number.to_i)
  end

  # Entry texts in position order, e.g. ["今日は雨だった。", "傘を忘れた。"].
  def full_journal
    entries.pluck(:content)
  end

  # The journal followup that whole-journal followups hang off, created on
  # first use.
  def journal_followup_for_followups!
    JournalFollowup.find_or_create_by!(journal: self)
  end

  # Journals also remember when they were last studied (for "finished
  # today").
  def mark_studied
    self.last_studied_at = Time.current
    super
  end

  # All entries as one text, in entry order.
  def full_text(separator = "\n\n")
    full_journal.join(separator)
  end

  def char_count
    self.full_journal.join.length
  end

  def previous_journal(journals)
    previous_in(journals)
  end
end
