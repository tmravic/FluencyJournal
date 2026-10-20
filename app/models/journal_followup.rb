class JournalFollowup < ApplicationRecord
  include FollowupOrigin

  belongs_to :journal
  has_many :followups, as: :origin, dependent: :destroy

  def content
    journal.full_text
  end

  def followup_journal
    journal
  end

  def followup_owner
    journal.user
  end

  def due_notes_shortcut?
    true
  end
end
