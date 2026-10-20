# frozen_string_literal: true

module AccessibleOwner
  extend ActiveSupport::Concern

  # Followup origin type => the scope of records of that type the current
  # user may reach. Adding an origin type means adding one line here.
  # (Followups are reachable as origins too, through accessible_followups,
  # but a followup of a followup is not itself listed there.)
  ORIGIN_SCOPES = {
    "Entry" => :accessible_entries,
    "Note" => :accessible_notes,
    "JournalFollowup" => :accessible_journal_followups,
    "AiOutput" => :accessible_ai_outputs,
    "Followup" => :accessible_followups
  }.freeze

  private

  def find_accessible_origin(origin_class, id)
    scope = ORIGIN_SCOPES.fetch(origin_class.to_s) { raise ActiveRecord::RecordNotFound }
    send(scope).find(id)
  end

  def find_accessible_entry(id)
    accessible_entries.find(id)
  end

  def find_accessible_note(id)
    accessible_notes.find(id)
  end

  def find_accessible_journal_followup(id)
    accessible_journal_followups.find(id)
  end

  def find_accessible_ai_query(id)
    accessible_ai_queries.find(id)
  end

  def find_accessible_ai_output(id)
    accessible_ai_outputs.find(id)
  end

  def find_accessible_followup(id)
    accessible_followups.find(id)
  end

  def accessible_entries
    Entry.where(journal_id: current_group.journals.select(:id))
  end

  def accessible_notes
    Current.user.notes
  end

  def accessible_journal_followups
    JournalFollowup.where(journal_id: current_group.journals.select(:id))
  end

  # A journal id must belong to the current group. A query with no journal is
  # visible only when its prompt followup origin is the current user's note.
  def accessible_ai_queries
    AiQuery.where(journal_id: current_group.journals.select(:id)).or(note_owned_ai_queries)
  end

  def note_owned_ai_queries
    note_ids = accessible_notes.select(:id)
    owned_ids = AiQuery.where(journal_id: nil).joins(prompt: :followup).where(
      followups: { origin_type: "Note", origin_id: note_ids }
    ).select(:id)

    AiQuery.where(id: owned_ids)
  end

  def accessible_ai_outputs
    AiOutput.where(ai_query_id: accessible_ai_queries.select(:id))
  end

  # Followups whose origin the user can reach. A nil origin matches none of
  # these, and neither does a Followup origin (it is not in this list).
  def accessible_followups
    ORIGIN_SCOPES.except("Followup")
      .map { |type, scope| Followup.where(origin_type: type, origin_id: send(scope).select(:id)) }
      .reduce(:or)
  end
end
