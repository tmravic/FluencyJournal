# The small interface FollowupsController and Followup use to ask any
# followup origin (Entry, AiOutput, Note, JournalFollowup, Followup) about
# itself, instead of switching on its class.
module FollowupOrigin
  extend ActiveSupport::Concern

  # The journal a followup on this origin belongs to, or nil (notes and
  # followups-of-followups have none).
  def followup_journal
    nil
  end

  # True when the followup form offers the short due-notes shortcut and
  # create expands it (journal followups and graded-quiz assessments).
  def due_notes_shortcut?
    false
  end

  # The graded-quiz assessment card, whose reference text is the whole
  # graded quiz rather than its own content.
  def quiz_assessment?
    false
  end

  # :short or :full, the due-notes option shown in the followup form.
  def due_notes_dropdown_format
    due_notes_shortcut? ? :short : :full
  end
end
