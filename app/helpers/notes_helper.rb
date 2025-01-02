module NotesHelper
  def hide_automatic_notes_option
    Note.categories.keys.reject { |key| key == "automatic" }.map { |key| [ key.humanize, key ] }
  end
end
