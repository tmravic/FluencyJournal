class CommitsController < ApplicationController
  require 'securerandom'
  before_action :set_entry, only: %i[ new create show edit update destroy ]
  before_action :set_commit, only: %i[ show edit update destroy ]
  before_action :get_ai_models

  # GET /commits/1 or /commits/1.json
  def show
  end

  # GET /commits/new
  def new
    @uuid = SecureRandom.uuid
    @commit = @entry.commits.build
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # GET /commits/1/edit
  def edit
  end

  # POST /commits or /commits.json
  def create
    @commit = @entry.commits.build(commit_params)

    respond_to do |format|
      if @commit.save
        format.html { redirect_to entry_path(@entry), notice: "Commit was successfully created." }
        format.json { render :show, status: :created, location: @commit }
        format.turbo_stream { flash.now[:notice] = "Commit was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @commit.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /commits/1 or /commits/1.json
  def update
    respond_to do |format|
      if @commit.update(commit_params)
        format.html { redirect_to entry_path(@entry), notice: "Commit was successfully updated." }
        format.json { render :show, status: :ok, location: @commit }
        format.turbo_stream { flash.now[:notice] = "Commit was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @commit.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /commits/1 or /commits/1.json
  def destroy
    @commit.destroy!

    respond_to do |format|
      format.html { redirect_to entry_path(@entry), status: :see_other, notice: "Commit was successfully destroyed." }
      format.json { head :no_content }
      format.turbo_stream { flash.now[:notice] = "Commit was successfully destroyed." }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_commit
    @commit = Commit.find(params.expect(:id))
  end

  def set_entry
    @entry = current_group.entries.find(params[:entry_id])
  end

  # Only allow a list of trusted parameters through.
  def commit_params
    params.expect(commit: [ :content, :entry_id ])
  end

end
