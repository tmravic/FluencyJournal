class EntriesController < ApplicationController
  require 'securerandom'
  before_action :set_entry, only: %i[ show edit update destroy ]
  before_action :set_api_key
  before_action :get_ai_models

  # GET /entries or /entries.json
  def index
    @uuid = SecureRandom.uuid
    @entries = current_group.entries.ordered
  end

  # GET /entries/1 or /entries/1.json
  def show
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
        format.html { redirect_to entries_path, notice: "Entry was successfully created." }
        # format.json { render :index, status: :created, location: @entry }
        format.turbo_stream
      else
        format.html { render :new, status: :unprocessable_entity }
        # format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /entries/1 or /entries/1.json
  def update
    respond_to do |format|
      if @entry.update(entry_params)
        # flash[:notice] = "..."
        format.html { redirect_to entries_path, notice: "Entry was successfully updated." }
        # format.json { render :show, status: :ok, location: @entry }
      else
        format.html { render :edit, status: :unprocessable_entity }
        # format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /entries/1 or /entries/1.json
  def destroy
    @entry.destroy!

    respond_to do |format|
      # flash[:notice] = "..."
      format.html { redirect_to entries_path, status: :see_other, notice: "Entry was successfully destroyed." }
      format.json { head :no_content }
      # format.turbo_stream
    end
  end

  def ai_request
    AiRequestJob.perform_later(ai_request_params, @api_key)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.update("ai_output", partial: "ai/output", locals: { generated_idea: "Processing..." }) }
      # flash[:notice] = "..."
      format.html { redirect_to entries_path, notice: "AI request sent." }
    end
  end

  private

  def ai_request_params
    params.require(:ai_request).permit(:prompt, :ai_model, :uuid)
  end

  def get_ai_models
    @ai_models = list_models(@api_key).map { |ai_model| ai_model['id'] }
  end

  def list_models(api_key)
    connection = set_faraday_connection(api_key)
    response = connection.get('/v1/models')

    if response.success?
      JSON.parse(response.body)["data"]
    else
      puts "Error: #{response.status} - #{response.body}"
    end
  end

  def set_faraday_connection(api_key)
    Faraday.new(url: 'https://api.openai.com') do |faraday|
      faraday.headers['Authorization'] = "Bearer #{api_key}"
      faraday.headers['Content-Type'] = 'application/json'
      faraday.adapter Faraday.default_adapter
    end
  end

  def set_api_key
    @api_key = Rails.application.credentials.openai[:api_key]
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_entry
    @entry = current_group.entries.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def entry_params
    params.expect(entry: [ :title, :content, :user_id ])
  end
end
