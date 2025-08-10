module FollowupsHelper
  def render_correct_cancel_button
    if @source_tag == 'notes_box'
      frame = "notes_box"
      path = session[:followup_from_todays_notes] ? notes_path : all_notes_path
    elsif @journal
      path = journal_path(@journal)
      frame = "ai_assistant"
    end

    link_to t("cancel"), path, class: "btn btn--light", data: { turbo_frame: frame }
  end
end
