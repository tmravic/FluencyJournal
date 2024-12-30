class NotesController < ApplicationController
  before_action :set_note, only: %i[ show edit update destroy ]

  def index
    @notes = Current.user&.notes.order(:next_study_date)
    # next_study_date = note from journals 1, 3, 7, etc in sequence of 2.5 rounded up
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def new
    @note = Note.new
  end

  def create
    @note = Current.user.notes.build(note_params)
    @note.next_study_date = DateTime.now + 1.days

    respond_to do |format|
      if @note.save
        format.html { redirect_to note_path(@note), notice: "Note was successfully created." }
        format.turbo_stream { flash.now[:notice] = "Note was successfully created." }
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
  end

  def update
    respond_to do |format|
      if @note.update(note_params)
        format.html { redirect_to entries_path, notice: "Note was successfully updated." }
        format.turbo_stream { flash.now[:notice] = "Note was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @note.destroy!

    respond_to do |format|
      format.html { redirect_to notes_path, status: :see_other, notice: "Note was successfully destroyed." }
      format.turbo_stream { flash.now[:notice] = "Note was successfully destroyed." }
    end
  end

  private

  def set_note
    @note = Current.user.notes.find(params.expect(:id))
  end

  def note_params
    params.expect(note: [ :content, :user_id, :entry_id, :category ])
  end
end
