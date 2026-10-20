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
  # scope :personal, -> {  }
  # scope :private, -> {  }
  # scope :public, -> {  }
  # scope :shared (either private or publish, not personal), -> {  }

  scope :finished_today, -> {
    where(last_studied_at: 24.hours.ago..).order(:last_studied_at)
  }

  # after_create_commit -> { broadcast_prepend_later_to "journals" }
  # after_update_commit -> { broadcast_replace_later_to "journals" }
  # after_destroy_commit -> { broadcast_remove_to "journals" }
  broadcasts_to ->(journals) { [ journals.group, "journals" ] }, inserts_by: :append
  # The signed stream name is generated from the array returned by the lambda
  # that is the first argument of the broadcasts_to method: [journals.group, "journals"].

  def entry_at(number)
    entries.find_by(position: number.to_i)
  end

  def full_journal
    entries.pluck(:content)
    # ["先日の日曜日に可愛い女の子と会いました。その子の人生についていろいろ教えてくれました。",
    #  "その子が年上のお金持ちの男性と遊んでいる話を聞いて驚きました。",
    #  "東京にいる面白い人との繋がりが多くてうらやましかった。"]
  end

  def char_count
    self.full_journal.join.length
  end

  def previous_journal(journals)
    previous_in(journals)
  end
end
