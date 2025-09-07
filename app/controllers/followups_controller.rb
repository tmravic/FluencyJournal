class FollowupsController < ApplicationController
  before_action :set_followup, only: %i[show destroy]
  ALLOWED_CLASSES = %w[Entry AiOutput Note Followup].freeze

  def new
    class_name = params[:class_name]
    klass = check_allowed_classes_for_followup(class_name)
    followup_origin_id = params[:id].to_i
    @followup_origin = klass.find(followup_origin_id)
    @reference_text = @followup_origin.content

    @followup_prompt = set_correct_prompt_type(class_name)
    @followup = @followup_prompt.build_followup

    @source_tag = params[:source_tag]
    @uuid = SecureRandom.uuid
    # @ai_models = get_ai_models

    if class_name == AiOutput
      @journal = @followup_origin.ai_query.journal
    elsif class_name == Entry
      @journal = @followup_origin.journal
    else
      session[:followup_from_todays_notes] = ActiveModel::Type::Boolean.new.cast(params[:followup_from_todays_notes])
      # this is just so the Cancel button knows which screen to return to
    end
  end

  def create
    @uuid = followup_params.dig(:followup_prompt, :uuid)
    @source_tag = followup_params[:source_tag]
    # need to know whether this came from "notes_box" or "ai_assistant"
    # when I render the turbo_streams view


    # define what object this followup references
    followup_origin_class = followup_params[:followup_origin_class].constantize
    followup_origin_id = followup_params[:followup_origin_id].to_i
    @followup_origin = followup_origin_class.find(followup_origin_id)
    # note, entry, or ai_output
    set_user_and_journal_based_on_origin_class(followup_origin_class)


    # create followup prompt
    followup_prompt_params = followup_params.dig(:followup_prompt)

    @followup_prompt = set_correct_prompt_type(
      followup_origin_class,
      params: followup_prompt_params
    )
    base_content = "Followup Question: #{followup_prompt_params.dig(:base_content)}"
    user_generated_content = "Reference text: #{followup_prompt_params.dig(:user_generated_content)}"
    raw_prompt = base_content + "\n" + user_generated_content
    @followup_prompt.raw_prompt = raw_prompt


    # create followup
    @followup_prompt.followup = Followup.new(
      origin: @followup_origin,
      source_tag: followup_params[:source_tag]
    )
    @followup_prompt.sent_role_prompt = @followup_prompt.role_prompt(@user)

    if @followup_prompt.save! && @followup_prompt.followup.save!

      FollowupRequestJob.perform_later(
        @user, @journal, @api_key, @followup_prompt, @followup_origin, @source_tag
      )

      notice = t("followup.request_sent")
      respond_to do |format|
        format.html { redirect_to followup_path(@followup), notice: notice }
        format.turbo_stream { flash.now[:notice] = notice }
      end
    end
  end

  def show
    unless @followup.origin.is_a?(Note)
      @followup_origin = @followup.origin
    end

    @source_tag = params.dig(:source_tag)
    set_user_and_journal_based_on_origin_class(@followup.origin.class)
  end

  def destroy
    @journal = Journal.find(params.dig(:journal)) if params.dig(:journal)
    @source_tag = params.dig(:source_tag)
    # ex: "ai_assistant" or "notes_box"
    # Used to find the HTML items for turbo streams to delete, ex:
    # "ai_assistant_answer_1"
    # "notes_box_answer_2"
    @followup.destroy
  end

  private

  def set_user_and_journal_based_on_origin_class(followup_origin_class)
    @user = Current.user
    if followup_origin_class == AiOutput
      @journal = @followup_origin.ai_query.journal
    elsif followup_origin_class == Entry
      @journal = @followup_origin.journal
    end
  end

  def set_correct_prompt_type(class_name, params = {})
    if is_vocab_or_grammar_note?(class_name)
      set_prompt_type_based_on_params(params, ExampleSentencePrompt)
    else
      set_prompt_type_based_on_params(params, FreeQuestionPrompt)
    end
  end

  def is_vocab_or_grammar_note?(class_name)
    class_name == Note && %w[vocab grammar].include?(@followup_origin.category)
  end

  def set_prompt_type_based_on_params(params, prompt_subclass_name)
    params.present? ? prompt_subclass_name.new(params[:params]) : prompt_subclass_name.new
  end

  def check_allowed_classes_for_followup(class_name)
    if ALLOWED_CLASSES.include?(class_name)
      class_name.constantize
    else
      raise(ArgumentError, "Invalid class: #{class_name}")
    end
  end

  def set_followup
    @followup = Followup.find(params.expect(:id))
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
        [ :source_tag, :followup_origin_class, :followup_origin_id,
          followup_prompt: [ :base_content, :user_generated_content, :raw_prompt, :ai_model, :uuid ]
        ]
    )
  end
end
