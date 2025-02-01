class NotesController < ApplicationController
  before_action :set_note, only: %i[ show edit update destroy mark_note_as_studied ]

  def index
    @source_tag = 'notes_box'
    @todays_notes = Current.user&.notes.next_to_study
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def all
    @source_tag = 'notes_box'
    @all_notes = Current.user&.notes.order(:next_study_date)
    respond_to do |format|
      format.html
      format.turbo_stream
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

    respond_to do |format|
      format.html
      format.turbo_stream { flash.now[:notice] = "You can customize this automatically created note before saving it." }
    end
  end

  def create
    @note = Current.user.notes.build(note_params)
    @note.next_study_date = DateTime.now

    if params[:ai_query_id].present?
      @ai_query = AiQuery.find(params[:ai_query_id])
      @ai_output = @ai_query.find_ai_output_by_identifier(params[:ai_output_identifier])
    end

    # Need to be able to create a note from All Notes or Today's notes
    # and stay on the same page with the same view context and header
    header_partial = get_header_from_view_context(params[:view_context])
    collection = get_collection_from_view_context(params[:view_context])
    previous_note = @note.previous_note

    respond_to do |format|
      if @note.save!
        @ai_output.update(made_note: true) if note_made_automatically?
        format.html { redirect_to note_path(@note), notice: "Note was successfully created." }
        format.turbo_stream do
          flash.now[:notice] = "Note was added to the end of today's study queue."
          render "notes/create", locals: {
            header_partial: header_partial,
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
    update_from_todays_notes = ActiveModel::Type::Boolean.new.cast(params[:update_from_todays_notes])
    respond_to do |format|
      if @note.update(note_params)
        format.html { redirect_to journals_path, notice: "Note was successfully updated." }
        format.turbo_stream do
          flash.now[:notice] = "Note was successfully updated."
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
    delete_from_todays_notes = params[:delete_from_todays_notes]

    respond_to do |format|
      format.html { redirect_to notes_path, status: :see_other, notice: "Note was successfully deleted." }
      format.turbo_stream do
        flash.now[:notice] = "Note was successfully deleted."
        render "notes/destroy", locals: { delete_from_todays_notes: delete_from_todays_notes }
      end
    end
  end

  def mark_note_as_studied
    new_interval = @note.last_interval * 2.5
    next_study_date = (new_interval).days.from_now
    notice = "Note will return on #{next_study_date.strftime("%m/%d/%Y")}"

    respond_to do |format|
      if @note.update(next_study_date: next_study_date, last_interval: new_interval)
        format.html { redirect_to note_path(@note), notice: notice }
        format.turbo_stream do
          flash.now[:notice] = notice
        end
      end
    end
  end

  private

  def note_made_automatically?
    @ai_query && @ai_output.present?
  end

  def get_header_from_view_context(view_context)
    if view_context == 'todays_notes'
      'notes/notes_header_todays'
    elsif view_context == 'all_notes'
      'notes/notes_header_all'
    end
  end

  def get_collection_from_view_context(view_context)
    if view_context == 'todays_notes'
      @todays_notes = Current.user&.notes.next_to_study
    elsif view_context == 'all_notes'
      @all_notes = Current.user&.notes.order(:next_study_date)
    end
  end

  def set_note
    @note = Current.user.notes.find(params.expect(:id))
  end

  def note_params
    params.expect(note: [ :content, :user_id, :journal_id, :category, :ai_query_id ])
  end
end
