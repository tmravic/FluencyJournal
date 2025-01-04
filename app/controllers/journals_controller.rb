class JournalsController < ApplicationController
  before_action :set_journal, only: %i[ show edit update destroy open_ai_assistant ]

  # GET /journals or /journals.json
  def index
    @journals = current_group.journals.ordered
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # GET /journals/1 or /journals/1.json
  def show
    cancel = params["cancel"]
    @entries = @journal.entries.ordered
    respond_to do |format|
      format.html
      format.turbo_stream do
        render "journals/show", locals: { cancel: cancel }
      end
    end
  end

  # GET /journals/new
  def new
    @journal = Journal.new
  end

  # GET /journals/1/edit
  def edit
  end

  # POST /journals or /journals.json
  def create
    @journal = current_group.journals.build(journal_params)
    @journal.user = Current.user

    respond_to do |format|
      if @journal.save
        # flash[:notice] = "..."
        format.html { redirect_to journal_path(@journal), notice: "Journal was successfully created." }
        format.json { render :index, status: :created, location: @journal }
        format.turbo_stream { flash.now[:notice] = "Journal was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @journal.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /journals/1 or /journals/1.json
  def update
    respond_to do |format|
      if @journal.update(journal_params)
        # flash[:notice] = "..."
        format.html { redirect_to journals_path, notice: "Journal was successfully updated." }
        format.json { render :show, status: :ok, location: @journal }
        format.turbo_stream { flash.now[:notice] = "Journal was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @journal.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /journals/1 or /journals/1.json
  def destroy
    @journal.destroy!

    respond_to do |format|
      # flash[:notice] = "..."
      format.html { redirect_to journals_path, status: :see_other, notice: "Journal was successfully deleted." }
      format.json { head :no_content }
      format.turbo_stream { flash.now[:notice] = "Journal was successfully deleted." }
    end
  end


  def ai_request
    entry_prompt = EntryPrompt.build(
      raw_prompt: ai_request_params["prompt"],
      ai_model: ai_request_params["ai_model"],
      uuid: ai_request_params["uuid"]
    )

    entry_prompt.original_language_prompt = entry_prompt.original_language
    entry_prompt.learning_language_prompt = entry_prompt.learning_language
    entry_prompt.sent_role_prompt = entry_prompt.role_prompt(
      Journal.find(ai_request_params[:journal_id]).user
    )
    entry_prompt.save!

    AiRequestJob.perform_later(ai_request_params, @api_key, entry_prompt)

    respond_to do |format|
      format.html { redirect_to journals_path, notice: "AI request sent." }
      format.turbo_stream
    end
  end

  def open_ai_assistant
    @ai_models = get_ai_models
    @uuid = SecureRandom.uuid

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def ai_request_params
    params.expect(ai_request: [ :prompt, :ai_model, :uuid, :journal_id ])
  end


  # Use callbacks to share common setup or constraints between actions.
  def set_journal
    @journal = current_group.journals.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def journal_params
    # OLD
    # user_params = params.require(:user).permit(:name, :favorite_pie)

    # NEW in Rails 8 using .expect(model: [:attribute1, :attribute2])
    params.expect(journal: [ :title, :content, :user_id ])
  end
end
