module FollowupsHelper
  def followup_turbo_frame(source_tag)
    "followup_output_#{source_tag}"
  end

  def render_correct_cancel_button
    if @source_tag == "notes_box"
      path = session[:followup_from_todays_notes] ? notes_path : all_notes_path
      link_to t("cancel"), path, class: "btn btn--light", data: { turbo_frame: "notes_box" }
    elsif @journal
      link_to t("cancel"),
              cancel_followups_path(source_tag: @source_tag),
              class: "btn btn--light",
              data: { turbo_stream: true }
    end
  end

  def close_followup_button(source_tag:)
    link_to t("note.close"),
            cancel_followups_path(source_tag: source_tag),
            class: "btn btn--dark",
            data: { turbo_stream: true }
  end
end
