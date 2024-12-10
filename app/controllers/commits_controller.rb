class CommitsController < ApplicationController
  before_action :set_commit, only: %i[ show edit update destroy ]

  # GET /commits or /commits.json
  def index
    @commits = Commit.all
  end

  # GET /commits/1 or /commits/1.json
  def show
  end

  # GET /commits/new
  def new
    @commit = Commit.new
  end

  # GET /commits/1/edit
  def edit
  end

  # POST /commits or /commits.json
  def create
    @commit = Commit.new(commit_params)

    respond_to do |format|
      if @commit.save
        format.html { redirect_to @commit, notice: "Commit was successfully created." }
        format.json { render :show, status: :created, location: @commit }
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
        format.html { redirect_to @commit, notice: "Commit was successfully updated." }
        format.json { render :show, status: :ok, location: @commit }
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
      format.html { redirect_to commits_path, status: :see_other, notice: "Commit was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_commit
      @commit = Commit.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def commit_params
      params.expect(commit: [ :content, :entry_id ])
    end
end
