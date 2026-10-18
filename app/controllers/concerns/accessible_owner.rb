# frozen_string_literal: true

module AccessibleOwner
  extend ActiveSupport::Concern

  private

  def find_accessible_origin(origin_class, id)
    if origin_class == Entry
      find_accessible_entry(id)
    elsif origin_class == Note
      find_accessible_note(id)
    elsif origin_class == AiOutput
      find_accessible_ai_output(id)
    elsif origin_class == Followup
      find_accessible_followup(id)
    elsif origin_class == JournalFollowup
      find_accessible_journal_followup(id)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def find_accessible_entry(id)
    accessible_entries.find(id)
  end

  def find_accessible_note(id)
    Current.user.notes.find(id)
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

  def accessible_journal_followups
    JournalFollowup.where(journal_id: current_group.journals.select(:id))
  end

  # A journal id must belong to the current group. A query with no journal is
  # visible only when its prompt followup origin is the current user's note.
  def accessible_ai_queries
    AiQuery.where(journal_id: current_group.journals.select(:id)).or(note_owned_ai_queries)
  end

  def note_owned_ai_queries
    note_ids = Current.user.notes.select(:id)
    owned_ids = AiQuery.where(journal_id: nil).joins(prompt: :followup).where(
      followups: { origin_type: "Note", origin_id: note_ids }
    ).select(:id)

    AiQuery.where(id: owned_ids)
  end

  def accessible_ai_outputs
    AiOutput.where(ai_query_id: accessible_ai_queries.select(:id))
  end

  # A nil origin matches none of these owners.
  def accessible_followups
    by_entry = Followup.where(origin_type: "Entry", origin_id: accessible_entries.select(:id))
    by_note = Followup.where(origin_type: "Note", origin_id: Current.user.notes.select(:id))
    by_journal_followup = Followup.where(
      origin_type: "JournalFollowup",
      origin_id: accessible_journal_followups.select(:id)
    )
    by_output = Followup.where(origin_type: "AiOutput", origin_id: accessible_ai_outputs.select(:id))

    by_entry.or(by_note).or(by_journal_followup).or(by_output)
  end
end
