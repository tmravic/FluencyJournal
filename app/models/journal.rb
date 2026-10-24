class Journal < ApplicationRecord
  include SchedulesStudy

  belongs_to :user
  belongs_to :group
  has_many :entries, -> { order(:position) }, dependent: :destroy
  has_and_belongs_to_many :notes
  has_many :ai_queries, dependent: :destroy
  has_many :quizzes, dependent: :destroy
  has_many :journal_followups, dependent: :destroy

  # Only checked when the title changes, so an existing longer title can
  # still be opened and its journal edited.
  MAX_TITLE_LENGTH = 255

  validates :title, presence: true
  validates :title, length: { maximum: MAX_TITLE_LENGTH }, if: :will_save_change_to_title?

  scope :ordered, -> { order(:next_study_date) }
  scope :alphabetical, -> { reorder(:title) }
  # The journals due for study when due_only, otherwise all of them.
  scope :due_or_all, ->(due_only) { due_only ? next_to_study : all }

  # Preloads the query history shown on the journal page (quizzes, followups).
  scope :with_query_history, -> {
    includes(ai_queries: [ :quizzes, :graded_quizzes, { prompt: :followup } ])
  }

  scope :finished_today, -> {
    where(last_studied_at: 24.hours.ago..).order(:last_studied_at)
  }

  # The signed stream name comes from the array this lambda returns:
  # [journal.group, "journals"].
  # Journal cards are pushed to the group's open journal pages. The Today's
  # and All pages render the card differently (Studied button or next review
  # date), and a broadcast has no page to ask, so each page subscribes to the
  # stream for its own mode and gets the card that page would render.
  CARD_MODES = %i[todays all].freeze

  def self.card_stream(group, mode)
    [ group, "journals", mode.to_s ]
  end

  after_create_commit  :broadcast_cards_created
  after_update_commit  :broadcast_cards_updated
  after_destroy_commit :broadcast_cards_removed

  def entry_at(number)
    entries.find_by(position: number.to_i)
  end

  # Entry texts in position order, e.g. ["今日は雨だった。", "傘を忘れた。"].
  def entry_texts
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
    entry_texts.join(separator)
  end

  def char_count
    self.entry_texts.join.length
  end

  def previous_journal(journals)
    previous_in(journals)
  end

  private

  def broadcast_cards_created
    CARD_MODES.each do |mode|
      next unless shown_on?(mode)

      broadcast_append_later_to(*self.class.card_stream(group, mode),
                                target: "journals", partial: "journals/journal",
                                locals: { journal: self, mode: mode })
    end
  end

  def broadcast_cards_updated
    CARD_MODES.each do |mode|
      stream = self.class.card_stream(group, mode)
      if shown_on?(mode)
        broadcast_replace_later_to(*stream, partial: "journals/journal",
                                            locals: { journal: self, mode: mode })
      else
        # Today's journals lists only what is due, so a journal that stopped
        # being due (studied, rescheduled) leaves that page like a reload.
        broadcast_remove_to(*stream)
      end
    end
  end

  def broadcast_cards_removed
    CARD_MODES.each { |mode| broadcast_remove_to(*self.class.card_stream(group, mode)) }
  end

  def shown_on?(mode)
    mode == :all || Journal.next_to_study.exists?(id: id)
  end
end
