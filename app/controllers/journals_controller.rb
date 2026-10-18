class JournalsController < ApplicationController
  before_action :set_journal, only: %i[ show edit update destroy open_ai_assistant mark_journal_as_studied reading_mode speak change_due_date update_due_date]
  before_action :set_from_all_or_todays, only: %i[ show edit new create mark_journal_as_studied]

  # GET /journals or /journals.json
  def index
    @todays_journals = current_group.journals.next_to_study
    @due_today = @todays_journals.count
    @from_all_or_todays = "todays"
    @journals_finished_today = finished_today_titles

    # Open today's notes in the notes_box frame
    @source_tag = "notes_box"
    @todays_notes = Current.user&.notes.next_to_study.includes(:followups, :journals)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def all
    @all_journals = current_group.journals.ordered
    @from_all_or_todays = "all"
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # GET /journals/1 or /journals/1.json
  def show
    @cancel = ActiveModel::Type::Boolean.new.cast(params["cancel"])
    @entries = @journal.entries.ordered
    @source_tag = "ai_assistant"

    # Eager load associations used by _previous_queries.html.erb to avoid N+1 queries
    # (followups, quizzes, prompt.class checks)
    @journal = current_group.journals
                            .includes(ai_queries: [:prompt, :quizzes, :followups])
                            .find(@journal.id)

    respond_to do |format|
      format.html
      format.turbo_stream do
        render "journals/show"
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
        format.html { redirect_to journal_path(@journal), notice: t("journal.created") }
        format.json { render :show, status: :created, location: @journal }
        format.turbo_stream { flash.now[:notice] = t("journal.created") }
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
        format.html { redirect_to journals_path, notice: t("journal.updated") }
        format.json { render :show, status: :ok, location: @journal }
        format.turbo_stream { flash.now[:notice] = t("journal.updated") }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @journal.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /journals/1 or /journals/1.json
  def destroy
    @journal.destroy!
    @from_all_or_todays = params.dig("from_all_or_todays")
    if @from_all_or_todays == "all"
      @all_journals = current_group.journals.ordered
    elsif @from_all_or_todays == "todays"
      @todays_journals = current_group.journals.next_to_study
    end

    respond_to do |format|
      # flash[:notice] = "..."
      format.html { redirect_to journals_path, status: :see_other, notice: t("journal.deleted") }
      format.json { head :no_content }
      format.turbo_stream { flash.now[:notice] = t("journal.deleted") }
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

  def mark_journal_as_studied
    new_interval = @journal.last_interval * 2.5
    next_study_date = (new_interval).days.from_now
    notice = t('journal.actions.will_return', date: next_study_date.strftime("%m/%d/%Y"))

    if @journal.update(
      next_study_date: next_study_date,
      last_interval: new_interval,
      last_studied_at: Time.current
    )
      @due_today = current_group.journals.next_to_study.count
      @journals_finished_today = finished_today_titles
      # All Journals still lists this journal, so it must not get today's empty state.
      @show_todays_journals_empty_state = @from_all_or_todays != "all" && @due_today.zero?
      respond_to do |format|
        format.html { redirect_to journal_path(@journal), notice: notice }
        format.turbo_stream do
          flash.now[:notice] = notice
        end
      end
    end
  end

  # GET /journals/:id/speak
  def speak
    language = XAiTtsService::LANGUAGE_CODES.fetch(Current.user.learning_language, "auto")
    text = @journal.entries.ordered.map(&:content).join("\n\n")

    audio = XAiTtsService.new(
      api_key: @api_key,
      text: text,
      language: language
    ).call

    send_data audio, type: "audio/mpeg", disposition: "inline"
  rescue XAiTtsService::TtsError
    head :service_unavailable
  end

  # GET /journals/:id/reading_mode
  def reading_mode
    @reading_mode = ActiveModel::Type::Boolean.new.cast(params[:reading_mode]) || false
    @entries = @journal.entries.ordered
    @source_tag = "ai_assistant"

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def change_due_date
  end

  def update_due_date
    @journal.update(next_study_date: params.dig(:next_study_date))

    respond_to do |format|
      format.turbo_stream
    end
  end

  def compare
    @journal = current_group.journals.find(params[:id])
    @todays_filter = ActiveModel::Type::Boolean.new.cast(params[:todays])

    @journals =
      if @todays_filter
        current_group.journals.next_to_study.reorder(:title)
      else
        current_group.journals.order(:title)
      end

    if ActiveModel::Type::Boolean.new.cast(params[:cancel])
      render html: helpers.turbo_frame_tag("compare"), layout: false
      return
    end

    selected_ids = Array(params[:journal_ids]).map(&:presence).compact
    @compared_journals =
      if selected_ids.any?
        current_group.journals
                     .where(id: selected_ids)
                     .includes(:entries)
                     .order(:title)
      else
        Journal.none
      end
  end


  private

  def set_journal
    @journal = current_group.journals.find(params.expect(:id))
  end

  def set_from_all_or_todays
    @from_all_or_todays =
      params.dig("journal", "from_all_or_todays").presence ||
      params.dig("from_all_or_todays").presence
  end

  def journal_params
    params.expect(journal: [ :title, :content, :user_id ])
  end

  def finished_today_titles
    current_group.journals.finished_today.pluck(:title).join(", ")
  end
end
