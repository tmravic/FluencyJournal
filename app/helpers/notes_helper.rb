module NotesHelper
  def hide_automatic_notes_option
    Note.categories.keys.reject { |key| key == "automatic" }.map do |key|
      [ I18n.t("activerecord.attributes.note.categories.#{key}"), key ]
    end
  end
end
