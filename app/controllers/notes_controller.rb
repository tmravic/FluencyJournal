class NotesController < ApplicationController
  include AccessibleOwner
  include StudyActions

  before_action :set_note, only: %i[
    show edit update destroy mark_note_as_studied change_due_date update_due_date
  ]
  before_action :set_notes_view_context, :set_note_with_links,
                only: %i[ link_journals update_journals cancel_link_journals ]

  def index
    @source_tag = SourceTag::NOTES_BOX
    @todays_notes = user_notes.todays_list
    @due_today = @todays_notes.count
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def all
    @source_tag = SourceTag::NOTES_BOX
    @all_notes = user_notes.all_list
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def drafts
    @source_tag = SourceTag::NOTES_BOX
    @draft_notes = user_notes.drafts_list
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def for_journal
    @source_tag = SourceTag::NOTES_BOX
    @journal = linkable_journals.find(params[:journal_id])
    @journal_notes = @journal.notes.all_list
    respond_to do |format|
      format.html
    end
  end

  def new
    @note = Note.new
    @view_context = params[:view_context]
  end

  def new_automatic
    @ai_query = find_accessible_ai_query(params[:ai_query_id])
    @ai_output = @ai_query.ai_outputs.find(params[:ai_output_id])
    @note = Note.new
    @view_context = params[:view_context]

    @user = Current.user

    respond_to do |format|
      format.html
      format.turbo_stream { flash.now[:notice] = t("note.customize_auto_note") }
    end
  end

  def create
    @note = user_notes.build(note_params)

    if params[:ai_query_id].present?
      @ai_query = find_accessible_ai_query(params[:ai_query_id])
      @ai_output = @ai_query.find_ai_output_by_identifier(params[:ai_output_identifier])
    end

    # Need to be able to create a note from All Notes or Today's notes
    # and stay on the same page with the same view context and header
    notes_list = notes_list_from_view_context(params[:view_context])
    collection = notes_for(params[:view_context])
    # notes/_note_display reads @todays_notes to keep the Today's Notes controls.
    @todays_notes = collection if params[:view_context] == "todays_notes"
    @source_tag = SourceTag::NOTES_BOX
    # The anchor is chosen before save, while this row is still off the list.
    # next_study_date is otherwise unset until validation.
    @note.set_initial_next_study_date
    previous_note = @note.previous_note(collection)

    respond_to do |format|
      if @note.save
        @ai_output.update(made_note: true) if note_made_automatically?
        format.html { redirect_to note_path(@note), status: :see_other, notice: t("note.note_added") }
        format.turbo_stream do
          flash.now[:notice] = t("note.note_added")
          render "notes/create", locals: {
            notes_list: notes_list,
            collection: collection,
            previous_note: previous_note
          }
        end
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def show
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def edit
    @update_from_todays_notes = params[:update_from_todays_notes]
  end

  def update
    @source_tag = SourceTag::NOTES_BOX
    respond_to do |format|
      if @note.update(note_params)
        format.html { redirect_to journals_path, status: :see_other, notice: t("note.updated") }
        format.turbo_stream do
          flash.now[:notice] = t("note.updated")
          # notes/_note_display reads @todays_notes to keep the Today's Notes controls.
          @todays_notes = user_notes.next_to_study if boolean_param(:update_from_todays_notes)
          render "notes/update"
        end
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @note.destroy!
    @delete_from_todays_notes = delete_came_from_todays_notes?
    @all_notes_empty = user_notes.empty?
    @todays_notes_empty = Current.user.no_notes_due?

    respond_to do |format|
      format.html { redirect_to notes_path, status: :see_other, notice: t("note.deleted") }
      format.turbo_stream do
        flash.now[:notice] = t("note.deleted")
      end
    end
  end

  def mark_note_as_studied
    @source_tag = SourceTag::NOTES_BOX
    respond_to_mark_studied(@note, "note.actions.will_return_html", note_path(@note)) do
      @due_today = Current.user.notes_due_count
      @todays_notes_empty = @due_today.zero?
    end
  end

  def change_due_date
    respond_to do |format|
      format.turbo_stream
    end
  end

  def update_due_date
    respond_to_due_date_update(@note)
  end

  def link_journals
    @journals = linkable_journals.order(:title)
  end

  def cancel_link_journals
  end

  def update_journals
    submitted = Array(journal_link_params[:journal_ids]).compact_blank
    @note.journal_ids = linkable_journals.where(id: submitted).ids

    if @note.save
      render :update_journals
    else
      @journals = linkable_journals.order(:title)
      render :link_journals, status: :unprocessable_entity
    end
  end

  private

  def delete_came_from_todays_notes?
    boolean_param(:delete_from_todays_notes)
  end

  def note_made_automatically?
    @ai_query && @ai_output.present?
  end

  def notes_list_from_view_context(view_context)
    view_context if NotesHeaderComponent::LISTS.include?(view_context) && view_context != "journal"
  end

  # The note list each view context shows. Other contexts (a journal's
  # notes, or none) have no list to place the new note in.
  NOTE_LISTS = {
    "todays_notes" => :todays_list,
    "all_notes" => :all_list,
    "draft_notes" => :drafts_list
  }.freeze

  def notes_for(view_context)
    list = NOTE_LISTS[view_context]
    user_notes.public_send(list) if list
  end

  # The signed-in user's notes. Authentication guarantees the user.
  def user_notes
    Current.user.notes
  end

  def set_note
    @note = user_notes.find(params.expect(:id))
  end

  # The journal-link actions re-render the note with its journals and followups.
  def set_note_with_links
    @note = user_notes.includes(:journals, :followups).find(params.expect(:id))
  end

  # The journals a note can be linked to and listed under: the user's own.
  # Groups share journals for viewing only; nobody links notes to a
  # group-mate's journal.
  def linkable_journals
    Current.user.journals
  end

  def set_notes_view_context
    @from_todays_notes = boolean_param(:from_todays_notes)
    @source_tag = SourceTag::NOTES_BOX
    @todays_notes = @from_todays_notes ? user_notes.next_to_study : nil
  end

  def journal_link_params
    params.fetch(:note, {}).permit(journal_ids: [])
  end

  def note_params
    params.expect(note: [ :content, :meaning, :extras, :category, :ai_query_id ])
  end
end
