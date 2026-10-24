class EntriesController < ApplicationController
  include SpeaksText
  include JournalScoped
  include HtmlResponsesOnly
  before_action :set_entry, only: %i[ edit update destroy speak cancel ]

  # GET /entries/new
  def new
    @uuid = SecureRandom.uuid
    @no_entries = @journal.entries.empty?
    @entry = @journal.entries.build
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # GET /entries/1/edit
  def edit
    @source_tag = SourceTag::AI_ASSISTANT
  end

  # GET /journals/:journal_id/entries/:id/cancel
  def cancel
    @source_tag = SourceTag::AI_ASSISTANT

    respond_to do |format|
      format.html { render_entry_display }
      format.turbo_stream { render_entry_display_stream }
    end
  end

  # POST /entries
  def create
    @entry = @journal.entries.build(entry_params)
    @source_tag = SourceTag::AI_ASSISTANT

    respond_to do |format|
      if @entry.save
        format.html { redirect_to journal_path(@journal), status: :see_other, notice: t("entry.created") }
        format.turbo_stream { flash.now[:notice] = t("entry.created") }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /entries/1
  def update
    @source_tag = SourceTag::AI_ASSISTANT
    respond_to do |format|
      if @entry.update(entry_params)
        format.html { redirect_to journal_path(@journal), status: :see_other, notice: t("entry.updated") }
        format.turbo_stream { flash.now[:notice] = t("entry.updated") }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # GET /journals/:journal_id/entries/:id/speak
  def speak
    speak_text(@entry.content)
  end

  # DELETE /entries/1
  def destroy
    @entry.destroy!
    @entries = @journal.entries.ordered

    respond_to do |format|
      format.html { redirect_to journal_path(@journal), status: :see_other, notice: t("entry.deleted") }
      format.turbo_stream { flash.now[:notice] = t("entry.deleted") }
    end
  end

  private

  def render_entry_display
    render partial: "entries/entry",
           locals: { entry: @entry, journal: @journal, source_tag: @source_tag },
           layout: false
  end

  def render_entry_display_stream
    render turbo_stream: turbo_stream.replace(
      dom_id(@entry),
      partial: "entries/entry",
      locals: { entry: @entry, journal: @journal, source_tag: @source_tag }
    )
  end

  def set_entry
    @entry = @journal.entries.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def entry_params
    params.expect(entry: [ :content ])
  end
end
