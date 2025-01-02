class EntriesController < ApplicationController
  before_action :set_entry, only: %i[ show edit update destroy open_journal ]

  # GET /entries or /entries.json
  def index
    @entries = current_group.entries.ordered
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # GET /entries/1 or /entries/1.json
  def show
    @commits = @entry.commits.ordered
    respond_to do |format|
      format.html # Renders the default HTML view for regular requests
      format.turbo_stream
    end
  end

  # GET /entries/new
  def new
    @entry = Entry.new
  end

  # GET /entries/1/edit
  def edit
  end

  # POST /entries or /entries.json
  def create
    @entry = current_group.entries.build(entry_params)
    @entry.user = Current.user

    respond_to do |format|
      if @entry.save
        # flash[:notice] = "..."
        format.html { redirect_to entry_path(@entry), notice: "Entry was successfully created." }
        format.json { render :index, status: :created, location: @entry }
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
        # flash[:notice] = "..."
        format.html { redirect_to entries_path, notice: "Entry was successfully updated." }
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

    respond_to do |format|
      # flash[:notice] = "..."
      format.html { redirect_to entries_path, status: :see_other, notice: "Entry was successfully deleted." }
      format.json { head :no_content }
      format.turbo_stream { flash.now[:notice] = "Entry was successfully deleted." }
    end
  end

  def ai_request
    AiRequestJob.perform_later(ai_request_params, @api_key)

    respond_to do |format|
      format.turbo_stream
      # flash[:notice] = "..."
      format.html { redirect_to entries_path, notice: "AI request sent." }
    end
  end

  def open_journal
    @ai_models = get_ai_models

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def ai_request_params
    params.expect(ai_request: [ :prompt, :ai_model, :uuid, :entry_id ])
  end


  # Use callbacks to share common setup or constraints between actions.
  def set_entry
    @entry = current_group.entries.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def entry_params
    # OLD
    # user_params = params.require(:user).permit(:name, :favorite_pie)

    # NEW in Rails 8 using .expect(model: [:attribute1, :attribute2])
    params.expect(entry: [ :title, :content, :user_id ])
  end
end
