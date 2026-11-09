class RewritesController < ApplicationController
  include JournalScoped

  # POST /journals/:journal_id/rewrite
  def create
    @rewrite = @journal.writing_rewrite
    @journal.rewrites.reset
    prepare_rewrite_screen

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to journal_path(@journal), status: :see_other }
    end
  end

  # GET /journals/:journal_id/rewrites/:id
  def show
    @rewrite = @journal.rewrites.find(params[:id])
    prepare_rewrite_screen

    respond_to do |format|
      format.turbo_stream { render :create }
      format.html { redirect_to journal_path(@journal), status: :see_other }
    end
  end

  # GET /journals/:journal_id/rewrite/original
  def original
    @journal.rewrites.where.missing(:entries).destroy_all
    @journal.rewrites.reset
    @entries = @journal.entries.ordered
    @source_tag = SourceTag::AI_ASSISTANT

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to journal_path(@journal), status: :see_other }
    end
  end

  private

  def prepare_rewrite_screen
    @source_tag = SourceTag::AI_ASSISTANT
  end
end
