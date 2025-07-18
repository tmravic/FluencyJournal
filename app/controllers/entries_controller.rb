class EntriesController < ApplicationController
  require 'securerandom'
  before_action :set_journal, only: %i[ new create show edit update destroy ]
  before_action :set_entry, only: %i[ show edit update destroy ]
  before_action :get_ai_models

  # GET /entries/1 or /entries/1.json
  def show
  end

  # GET /entries/new
  def new
    @uuid = SecureRandom.uuid
    @entry = @journal.entries.build
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # GET /entries/1/edit
  def edit
  end

  # POST /entries or /entries.json
  def create
    @entry = @journal.entries.build(entry_params)
    @source_tag = 'ai_assistant'

    respond_to do |format|
      if @entry.save
        format.html { redirect_to journal_path(@journal), notice: "Entry was successfully created." }
        format.json { render :show, status: :created, location: @entry }
        format.turbo_stream { flash.now[:notice] = "Entry was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /entries/1 or /entries/1.json
  def update
    respond_to do |format|
      if @entry.update(entry_params)
        format.html { redirect_to journal_path(@journal), notice: "Entry was successfully updated." }
        format.json { render :show, status: :ok, location: @entry }
        format.turbo_stream { flash.now[:notice] = "Entry was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /entries/1 or /entries/1.json
  def destroy
    @entry.destroy!
    @entries = @journal.entries.ordered

    respond_to do |format|
      format.html { redirect_to journal_path(@journal), status: :see_other, notice: "Entry was successfully deleted." }
      format.json { head :no_content }
      format.turbo_stream { flash.now[:notice] = "Entry was successfully deleted." }
    end
  end

  private

  def set_entry
    @entry = Entry.find(params.expect(:id))
  end

  def set_journal
    @journal = current_group.journals.find(params[:journal_id])
  end

  # Only allow a list of trusted parameters through.
  def entry_params
    params.expect(entry: [ :content, :journal_id ])
  end
end
