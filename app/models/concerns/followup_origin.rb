# The small interface FollowupsController and Followup use to ask any
# followup origin (Entry, AiOutput, Note, JournalFollowup, Followup) about
# itself, instead of switching on its class.
module FollowupOrigin
  extend ActiveSupport::Concern

  # Each origin also answers followup_owner: the user whose material the
  # followup is about (Followup#user).

  # The journal a followup on this origin belongs to, or nil (notes and
  # followups-of-followups have none).
  def followup_journal
    nil
  end

  # True when the followup form offers the short due-notes shortcut and
  # create expands it (journal followups).
  def due_notes_shortcut?
    false
  end

  # :short or :full, the due-notes option shown in the followup form.
  def due_notes_dropdown_format
    due_notes_shortcut? ? :short : :full
  end
end
