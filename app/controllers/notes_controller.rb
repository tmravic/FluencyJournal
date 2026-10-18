class NotesController < ApplicationController
  before_action :set_note, only: %i[
    show edit update destroy mark_note_as_studied change_due_date update_due_date
    link_journals update_journals cancel_link_journals
  ]

  def index
    @source_tag = "notes_box"
    @todays_notes = Current.user&.notes.next_to_study.includes(:followups, :journals)
    @due_today = @todays_notes.count
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def all
    @source_tag = "notes_box"
    @all_notes = Current.user&.notes.order(:next_study_date).includes(:followups, :journals)
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def drafts
    @source_tag = "notes_box"
    @draft_notes = Current.user&.notes.draft_journal.order(:next_study_date).includes(:followups, :journals)
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def for_journal
    @source_tag = "notes_box"
    @journal = Current.user.journals.find(params[:journal_id])
    @journal_notes = @journal.notes.order(:next_study_date).includes(:followups, :journals)
    respond_to do |format|
      format.html
    end
  end

  def new
    @note = Note.new
    @view_context = params[:view_context]
  end

  def new_automatic
    @ai_output = AiOutput.find(params[:ai_output_id].to_i)
    @note = Note.new
    @view_context = params[:view_context]
    @ai_query = AiQuery.find(params[:ai_query_id])
    @user = Current.user

    respond_to do |format|
      format.html
      format.turbo_stream { flash.now[:notice] = t("note.customize_auto_note") }
    end
  end

  def create
    @note = Current.user.notes.build(note_params)

    if params[:ai_query_id].present?
      @ai_query = AiQuery.find(params[:ai_query_id])
      @ai_output = @ai_query.find_ai_output_by_identifier(params[:ai_output_identifier])
    end

    # Need to be able to create a note from All Notes or Today's notes
    # and stay on the same page with the same view context and header
    notes_list = notes_list_from_view_context(params[:view_context])
    collection = get_collection_from_view_context(params[:view_context])
    @source_tag = "notes_box"
    # The anchor is chosen before save, while this row is still off the list.
    # next_study_date is otherwise unset until validation.
    @note.set_initial_next_study_date
    previous_note = @note.previous_note(collection)

    respond_to do |format|
      if @note.save
        @ai_output.update(made_note: true) if note_made_automatically?
        format.html { redirect_to note_path(@note), notice: t("note.note_added") }
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
    @source_tag = "notes_box"
    update_from_todays_notes = ActiveModel::Type::Boolean.new.cast(params[:update_from_todays_notes])
    respond_to do |format|
      if @note.update(note_params)
        format.html { redirect_to journals_path, notice: t("note.updated") }
        format.turbo_stream do
          flash.now[:notice] = t("note.updated")
          if update_from_todays_notes
            @todays_notes = Current.user&.notes.next_to_study
            render "notes/update", locals: { collection: @todays_notes }
          else
            @all_notes = Current.user&.notes.order(:next_study_date)
            render "notes/update", locals: { collection: @all_notes }
          end
        end
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @note.destroy!
    @delete_from_todays_notes = delete_came_from_todays_notes?
    @all_notes_empty = Current.user&.notes.empty?
    @todays_notes_empty = Current.user&.notes.next_to_study.empty?

    respond_to do |format|
      format.html { redirect_to notes_path, status: :see_other, notice: t("note.deleted") }
      format.turbo_stream do
        flash.now[:notice] = t("note.deleted")
      end
    end
  end

  def mark_note_as_studied
    @source_tag = "notes_box"
    @note.schedule_after_study
    notice = t(
      "note.actions.will_return_html",
      date: helpers.local_date(@note.next_study_date, format: "%Y-%m-%d")
    ).html_safe

    if @note.save
      @due_today = Current.user&.notes.next_to_study.count
      @todays_notes_empty = @due_today.to_i.zero?
      respond_to do |format|
        format.html { redirect_to note_path(@note), notice: notice }
        format.turbo_stream do
          flash.now[:notice] = notice
        end
      end
    end
  end

  def change_due_date
    respond_to do |format|
      format.turbo_stream
    end
  end

  def update_due_date
    if @note.update(next_study_date: params.dig(:next_study_date))
      respond_to do |format|
        format.turbo_stream
      end
    end
  end

  def link_journals
    set_notes_view_context
    @note = Current.user.notes.includes(:journals).find(params[:id])
    @journals = Current.user.journals.order(:title)
  end

  def cancel_link_journals
    set_notes_view_context
    @note = Current.user.notes.includes(:followups, :journals).find(params[:id])
  end

  def update_journals
    set_notes_view_context
    @note = Current.user.notes.includes(:journals, :followups).find(params[:id])
    @note.journal_ids = journal_link_params[:journal_ids] || []

    if @note.save
      render :update_journals
    else
      @journals = Current.user.journals.order(:title)
      render :link_journals, status: :unprocessable_entity
    end
  end

  private

  def delete_came_from_todays_notes?
    ActiveModel::Type::Boolean.new.cast(params[:delete_from_todays_notes])
  end

  def note_made_automatically?
    @ai_query && @ai_output.present?
  end

  def notes_list_from_view_context(view_context)
    view_context if NotesHeaderComponent::LISTS.include?(view_context) && view_context != "journal"
  end

  def get_collection_from_view_context(view_context)
    case view_context
    when "todays_notes"
      @todays_notes = Current.user&.notes.next_to_study.includes(:followups, :journals)
    when "all_notes"
      @all_notes = Current.user&.notes.order(:next_study_date).includes(:followups, :journals)
    when "draft_notes"
      @draft_notes = Current.user&.notes.draft_journal.order(:next_study_date).includes(:followups, :journals)
    end
  end

  def set_note
    @note = Current.user.notes.find(params.expect(:id))
  end

  def set_notes_view_context
    @from_todays_notes = ActiveModel::Type::Boolean.new.cast(params[:from_todays_notes])
    @source_tag = "notes_box"
    @todays_notes = @from_todays_notes ? Current.user&.notes.next_to_study : nil
  end

  def journal_link_params
    params.fetch(:note, {}).permit(journal_ids: [])
  end

  def note_params
    params.expect(note: [ :content, :meaning, :extras, :user_id, :journal_ids, :category, :ai_query_id ])
  end
end
