class FollowupsController < ApplicationController
  include TemplatePromptConcern
  include AccessibleOwner

  before_action :set_followup, only: %i[show destroy]
  ALLOWED_CLASSES = %w[Entry AiOutput Note Followup JournalFollowup].freeze
  # What followups/_form posts as the origin class when it was rendered
  # without an origin ("Unknown", id 0), besides a blank value.
  FORM_PLACEHOLDER_ORIGIN_CLASSES = %w[Unknown 0].freeze

  def new
    @source_tag = SourceTag.parse(params[:source_tag])
    return redirect_to(root_path) if params[:class_name].blank?

    @followup_prompt = FreeQuestionPrompt.new
    @followup = @followup_prompt.build_followup
    @followup_origin = new_followup_origin(origin_class_for(params[:class_name]))
    return redirect_to(root_path) unless @followup_origin

    @journal = @followup_origin.followup_journal
    @reference_text = followup_reference_text(@followup_origin)
    @followup_template_prompts = get_template_prompts_scoped_by_user(
      Current.user,
      due_notes_dropdown: @followup_origin.due_notes_dropdown_format
    )
    @uuid = SecureRandom.uuid
    # Cancel chooses today's notes or all notes from this flag.
    @followup_from_todays_notes = boolean_param(:followup_from_todays_notes) if @journal.nil?

    render layout: false if @source_tag == SourceTag::AI_ASSISTANT
  end

  def create
    @uuid = followup_params.dig(:followup_prompt, :uuid)
    @source_tag = SourceTag.parse(followup_params[:source_tag])
    # need to know whether this came from "notes_box" or "ai_assistant"
    # when I render the turbo_streams view


    # define what object this followup references
    origin_class_str = followup_params[:followup_origin_class].to_s
    return respond_missing_origin(origin_class_str) if missing_origin_class?(origin_class_str)

    @followup_origin = saved_followup_origin(origin_class_for(origin_class_str))
    set_user_and_journal

    if saving_new_template_prompt?
      base_content = followup_params.dig(:followup_prompt, :base_content).to_s.strip

      if base_content.present?
        followup_template_prompt = FollowupTemplatePrompt.find_or_create_by!(
          base_content: base_content,
          user: Current.user
        )
      end
    end

    @followup_template_prompts = get_template_prompts_scoped_by_user(
      Current.user,
      due_notes_dropdown: @followup_origin.due_notes_dropdown_format
    )

    # create followup prompt
    followup_prompt_params = followup_params.dig(:followup_prompt).to_h

    if @followup_origin.due_notes_shortcut?
      expanded_base_content = expand_due_notes_prompt(
        followup_prompt_params[:base_content],
        Current.user
      )
      followup_prompt_params[:base_content] = expanded_base_content if expanded_base_content
    end

    @followup_prompt = FreeQuestionPrompt.new(followup_prompt_params)
    base_content = "Followup Question: #{followup_prompt_params[:base_content]}"
    user_generated_content = "Reference text: #{followup_prompt_params.dig(:user_generated_content)}"
    raw_prompt = base_content + "\n" + user_generated_content
    @followup_prompt.raw_prompt = raw_prompt


    # create followup
    @followup_prompt.followup = Followup.new(
      origin: @followup_origin,
      source_tag: @source_tag
    )
    @followup_prompt.followup_template_prompt = followup_template_prompt if followup_template_prompt

    @followup_prompt.sent_role_prompt = @followup_prompt.role_prompt(@user, @journal)

    unless save_followup_prompt
      head :unprocessable_entity
      return
    end

    FollowupRequestJob.perform_later(
      @user, @journal, @followup_prompt, @followup_origin, @source_tag
    )

    notice = t("followup.request_sent")
    respond_to do |format|
      format.html { redirect_to followup_path(@followup_prompt.followup), status: :see_other, notice: notice }
      format.turbo_stream { flash.now[:notice] = notice }
    end
  end

  def show
    @followup_origin = @followup.origin unless @followup.from_note?

    @source_tag = SourceTag.parse(params[:source_tag])
    set_user_and_journal(@followup.origin)
  end

  def cancel
    @source_tag = SourceTag.parse(params[:source_tag]) || SourceTag::AI_ASSISTANT

    respond_to do |format|
      format.turbo_stream
    end
  end

  def destroy
    @journal = current_group.journals.find(params.dig(:journal)) if params.dig(:journal)
    @source_tag = SourceTag.parse(params[:source_tag])
    @display_frames = display_frames_for(params[:display_frame], @source_tag)
    return_to = after_destroy_path

    if @followup.destroy
      respond_to do |format|
        format.html { redirect_to return_to, status: :see_other }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to return_to, alert: t("followup.delete_failed") }
        format.turbo_stream { head :unprocessable_entity }
      end
    end
  end

  private

  # The origin the new-followup form is for, or nil when no id was given.
  # A journal followup is built (not saved) on the journal from journal_id
  # (or id); create saves it.
  def new_followup_origin(klass)
    if klass == JournalFollowup
      followup_journal(params[:journal_id].presence || params[:id]).journal_followups.build
    elsif params[:id].present?
      find_accessible_origin(klass, params[:id].to_i)
    end
  end

  # The origin create attaches the followup to. A journal has one journal
  # followup, created on first use.
  def saved_followup_origin(klass)
    if klass == JournalFollowup
      followup_journal(followup_params[:journal_id]).journal_followup_for_followups!
    else
      find_accessible_origin(klass, followup_params[:followup_origin_id].to_i)
    end
  end

  # Journal followups may be asked on any journal in the group.
  def followup_journal(journal_id)
    current_group.journals.find(journal_id)
  end

  # What the form pre-fills as the reference text: the origin's content,
  # or for a graded-quiz assessment the whole graded quiz.
  def followup_reference_text(origin)
    return origin.content unless origin.quiz_assessment?

    helpers.quiz_graded_entries_reference_text(origin.ai_query, Current.user)
  end

  # A blank or placeholder origin class means the form never had an origin.
  # That is answered with 422 / a redirect, unlike an unknown class name,
  # which origin_class_for turns into a 404.
  def missing_origin_class?(class_name)
    class_name.blank? || class_name.in?(FORM_PLACEHOLDER_ORIGIN_CLASSES)
  end

  def respond_missing_origin(class_name)
    Rails.logger.error "FOLLOWUPS#CREATE: Received invalid followup_origin_class=#{class_name.inspect} (id=#{followup_params[:followup_origin_id]}). This usually means the form was rendered before @followup_origin was set."
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.html { redirect_to root_path, status: :see_other, alert: t("followup.invalid_origin") }
    end
  end

  # The turbo frames destroy.turbo_stream.erb clears: the one the request
  # names, or the followup frame plus the source frame (e.g.
  # "followup_output_notes_box" and "notes_box"). Items inside them are
  # named like "notes_box_answer_2".
  def display_frames_for(display_frame, source_tag)
    return [ display_frame ] if display_frame.present?

    [ helpers.followup_turbo_frame(source_tag), source_tag ].uniq
  end

  def after_destroy_path
    if @journal
      journal_path(@journal)
    elsif @followup.from_note?
      notes_path
    else
      root_path
    end
  end

  # Saves the prompt and its followup together. Returns false (and writes
  # nothing) when either is invalid, so create can answer 422 instead of
  # raising ActiveRecord::RecordInvalid.
  def save_followup_prompt
    Prompt.transaction do
      (@followup_prompt.save && @followup_prompt.followup.save) || raise(ActiveRecord::Rollback)
    end.present?
  end

  def saving_new_template_prompt?
    params[:save_as_template] == "1"
  end

  # The followup is sent as the signed-in user, in the origin's journal
  # (none for notes and followups-of-followups).
  def set_user_and_journal(origin = @followup_origin)
    @user = Current.user
    @journal = origin&.followup_journal
  end

  # Turns a whitelisted class name from params into the origin model class.
  def origin_class_for(class_name)
    raise ActiveRecord::RecordNotFound unless ALLOWED_CLASSES.include?(class_name)

    class_name.constantize
  end

  def set_followup
    @followup = find_accessible_followup(params.expect(:id))
  end

  def followup_params
    # "followup"=>{
    #   "followup_origin_class"=>"Entry",
    #   "followup_origin_id"=>"4",
    #   "source_tag"=>"",
    #   "followup_prompt"=>{
    #     "base_content"=>"What are the readings for all the kanji in this sentence?",
    #     "user_generated_content"=>"お寺に祈りに行って、「好きな女の子が私の彼女になりますように」とお願いしました。",
    #     "uuid"=>"c9b63573-f7de-45c5-98ed-47c49109becb",
    #     "ai_model"=>"grok-3"
    #   }
    # }
    params.expect(
      followup:
        [ :source_tag, :followup_origin_class, :followup_origin_id, :journal_id,
          followup_prompt: [ :base_content, :user_generated_content, :raw_prompt, :ai_model, :uuid ]
        ]
    )
  end
end
