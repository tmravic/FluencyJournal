class NotesController < ApplicationController
  before_action :set_note

  def index
    @notes = Current.user&.notes
    # @notes_for_entry = I need a before_action to :set_entry unless they're on the landing page
    # @recommended_notes = note from journals 1, 3, 7, etc in sequence of 2.5 rounded up
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def set_note
    # @note = Current.user.notes.find(params.expect(:id))
  end

  def note_params
    params.expect(note: [ :content, :user_id, :entry_id, :category ])
  end
end
