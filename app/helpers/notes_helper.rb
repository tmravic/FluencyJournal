module NotesHelper
  def reject_automatic_notes
    Note.categories.keys.reject { |key| key == "automatic" }.map { |key| [ key.humanize, key ] }
  end
end
