class JournalsController < ApplicationController
  include SpeaksText
  include StudyActions
  before_action :set_journal, only: %i[ edit update destroy open_ai_assistant mark_journal_as_studied reading_mode speak change_due_date update_due_date]
  before_action :set_from_all_or_todays, only: %i[ show edit new create mark_journal_as_studied]

  # GET /journals or /journals.json
  def index
    @todays_journals = current_group.journals.next_to_study
    @due_today = @todays_journals.count
    @from_all_or_todays = "todays"
    @journals_finished_today = finished_today_titles

    # Open today's notes in the notes_box frame
    @source_tag = SourceTag::NOTES_BOX
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
    # One query, with what _previous_queries.html.erb needs preloaded.
    @journal = current_group.journals.with_query_history.find(params.expect(:id))
    @cancel = boolean_param(:cancel)
    @entries = @journal.entries.ordered
    @source_tag = SourceTag::AI_ASSISTANT

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
        format.html { redirect_to journal_path(@journal), status: :see_other, notice: t("journal.created") }
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
        format.html { redirect_to journals_path, status: :see_other, notice: t("journal.updated") }
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
    @uuid = SecureRandom.uuid

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def mark_journal_as_studied
    respond_to_mark_studied(@journal, "journal.actions.will_return_html", journal_path(@journal)) do
      @due_today = current_group.journals.next_to_study.count
      @journals_finished_today = finished_today_titles
    end
  end

  # GET /journals/:id/speak
  def speak
    speak_text(@journal.full_text)
  end

  # GET /journals/:id/reading_mode
  def reading_mode
    @reading_mode = boolean_param(:reading_mode)
    @entries = @journal.entries.ordered
    @source_tag = SourceTag::AI_ASSISTANT

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def change_due_date
  end

  def update_due_date
    respond_to_due_date_update(@journal)
  end

  def compare
    @journal = current_group.journals.find(params[:id])
    @todays_filter = boolean_param(:todays)

    @journals =
      if @todays_filter
        current_group.journals.next_to_study.reorder(:title)
      else
        current_group.journals.order(:title)
      end

    if boolean_param(:cancel)
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
    params.expect(journal: [ :title, :content ])
  end

  def finished_today_titles
    current_group.journals.finished_today.pluck(:title).join(", ")
  end
end
