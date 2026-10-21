# The "use my due notes" followup template: the user's due notes (drafts
# excluded) listed after a fixed prefix, or a short label in the
# dropdown.
class DueNotesTemplate
  # Lists longer than this are cut to 398 characters plus "..." (401 in
  # all). That is the current behaviour, kept on purpose; it is not
  # String#truncate(400).
  MAX_LIST_LENGTH = 400
  KEPT_LENGTH = 398

  def initialize(user)
    @user = user
  end

  def available?
    contents.any?
  end

  # The dropdown text: the short label (:short) or the full prompt
  # (:full). nil when nothing is due.
  def text(format = :full)
    return nil unless available?
    return short_label if format == :short

    full_text
  end

  # True when +base_content+ is this template, as the short label or a
  # full prompt (possibly with an older list).
  def selected_by?(base_content)
    return false if base_content.blank?

    normalized = base_content.strip
    normalized == short_label || normalized.start_with?(prefix)
  end

  def short_label
    I18n.t("prompt_templates.due_notes_short")
  end

  def prefix
    I18n.t(
      "prompt_templates.due_notes_prefix",
      default: "Create example sentences or explanations for these due notes: "
    )
  end

  private

  def full_text
    list = contents.join(", ")
    list = list[0...KEPT_LENGTH] + "..." if list.length > MAX_LIST_LENGTH

    "#{prefix}#{list}"
  end

  def contents
    @contents ||= Note.by_user(@user).due_for_study_prompt.pluck(:content).compact_blank.uniq
  end
end
