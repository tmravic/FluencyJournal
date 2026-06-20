module NotesHelper
  def note_category_options
    Note.categories.keys.map do |key|
      [ I18n.t("activerecord.attributes.note.categories.#{key}"), key ]
    end
  end

  def determine_cancel_path
    if @update_from_todays_notes == "true"
      notes_path
    else
      all_notes_path
    end
  end
end
