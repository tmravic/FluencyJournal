require "rails_helper"
require_relative "../support/characterization_snapshot"

# Characterization of FollowupsController (new, create, show, destroy) for
# every followup origin type, recorded before the origin-interface refactor
# (C2, C4, C11, C12, C21, M6, K5). The AI job is stubbed; nothing is sent.
RSpec.describe "Followups characterization", type: :request do
  snapshot = CharacterizationSnapshot.new("followups")
  turbo = { "Accept" => "text/vnd.turbo-stream.html" }

  def make_user(group, label, learning: "Japanese")
    User.create!(
      email_address: "fc-#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "password", original_language: "English", learning_language: learning, group: group
    )
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def output!(query, identifier, content)
    query.ai_outputs.create!(identifier: identifier, content: content, made_note: false)
  end

  # Builds one of every origin type and remembers a stable label for each
  # record, so snapshots never contain database ids.
  let!(:world) do
    group = Group.create!(name: "FC #{SecureRandom.hex(4)}")
    other_group = Group.create!(name: "FC other #{SecureRandom.hex(4)}")
    me = make_user(group, "me")
    mate = make_user(group, "mate")
    outsider = make_user(other_group, "outsider")

    journal = Journal.create!(title: "Mine", user: me, group: group, last_interval: 1)
    entry = journal.entries.create!(content: "今日は雨だった。")
    journal.entries.create!(content: "傘を忘れた。")
    mate_journal = Journal.create!(title: "Mate's", user: mate, group: group, last_interval: 1)
    mate_entry = mate_journal.entries.create!(content: "友達の文。")
    outsider_journal = Journal.create!(title: "Outside", user: outsider, group: other_group, last_interval: 1)
    outsider_entry = outsider_journal.entries.create!(content: "外の文。")

    correction_prompt = EntryPrompt.create!(raw_prompt: "x", ai_model: "m", uuid: SecureRandom.uuid, sent_role_prompt: "r")
    correction = AiQuery.create!(
      journal: journal, prompt: correction_prompt,
      raw_response: { "change_1" => { "content" => "雨だ → 雨だった", "explanation_en" => "Past tense." },
                      "corrected_text" => { "text" => "今日は雨だった。" } }.to_json
    )
    change_output = output!(correction, "1", "雨だ\n↓\n雨だった")

    grading_prompt = QuizResultPrompt.create!(raw_prompt: "x", ai_model: "m", uuid: SecureRandom.uuid, sent_role_prompt: "r")
    grading = AiQuery.create!(
      journal: journal, prompt: grading_prompt,
      raw_response: { "entry_1" => { "content" => "It rain → It rained", "explanation_en" => "Tense." },
                      "entry_2" => { "content" => "umbrella", "explanation_en" => "Fine." },
                      "assessment" => { "text" => "Watch your tenses." } }.to_json
    )
    output!(grading, "1", "It rain\n↓\nIt rained")
    output!(grading, "2", "umbrella")
    assessment = output!(grading, "assessment", "Watch your tenses.")

    note = me.notes.create!(content: "雨 (あめ) rain")
    me.notes.create!(content: "傘 (かさ) umbrella")
    journal_followup = journal.journal_followups.create!

    parent_prompt = FreeQuestionPrompt.create!(raw_prompt: "x", ai_model: "m", uuid: SecureRandom.uuid, sent_role_prompt: "r")
    parent_followup = Followup.create!(prompt: parent_prompt, origin: entry, source_tag: "ai_assistant")
    FollowupTemplatePrompt.create!(user: me, base_content: "Explain the grammar.")

    {
      me: me, journal: journal, entry: entry, mate_entry: mate_entry, outsider_entry: outsider_entry,
      change_output: change_output, assessment: assessment, note: note,
      journal_followup: journal_followup, parent_followup: parent_followup, mate_journal: mate_journal
    }
  end

  def label(record)
    return nil if record.nil?
    return "#{record.class.name}(new, journal: #{label(record.journal)})" if record.new_record?

    world.find { |_name, value| value.is_a?(ActiveRecord::Base) && value.class == record.class && value.id == record.id }&.first&.to_s ||
      "#{record.class.name}(unlabelled)"
  end

  def normalize(text)
    return text unless text.is_a?(String)

    world.each_value do |record|
      next unless record.is_a?(ActiveRecord::Base)

      text = text.gsub(%r{/#{record.class.model_name.route_key}/#{record.id}\b}, "/#{record.class.model_name.route_key}/<#{label(record)}>")
    end
    text.gsub(%r{/(followups|ai_outputs|ai_queries)/\d+}, '/\1/<id>').gsub(/\d{4,}/, "<id>")
  end

  def ivars(*names)
    names.to_h do |name|
      value = controller.instance_variable_get("@#{name}")
      [ name, value.is_a?(ActiveRecord::Base) ? label(value) : value ]
    end
  end

  def page_observation
    {
      status: response.status,
      location: normalize(response.location),
      layout: response.body.include?("<html"),
      **ivars(:source_tag, :reference_text, :followup_template_prompts, :followup_from_todays_notes),
      journal: label(controller.instance_variable_get(:@journal)),
      followup_origin: label(controller.instance_variable_get(:@followup_origin))
    }
  end

  # Some paths raise today (they are pinned as such, not fixed here).
  def observing
    yield
    nil
  rescue StandardError => e
    cause = e.respond_to?(:cause) && e.cause ? e.cause : e
    { error: cause.class.name, message: cause.message.sub(/ for an instance of .*/, "") }
  end

  before { sign_in(world[:me]) }

  describe "GET new" do
    {
      "entry/ai_assistant" => -> { { class_name: "Entry", id: world[:entry].id, source_tag: "ai_assistant" } },
      "entry/notes_box" => -> { { class_name: "Entry", id: world[:entry].id, source_tag: "notes_box" } },
      "group_mate_entry" => -> { { class_name: "Entry", id: world[:mate_entry].id, source_tag: "ai_assistant" } },
      "ai_output/change" => -> { { class_name: "AiOutput", id: world[:change_output].id, source_tag: "ai_assistant" } },
      "ai_output/quiz_assessment" => -> { { class_name: "AiOutput", id: world[:assessment].id, source_tag: "ai_assistant" } },
      "note/todays" => -> { { class_name: "Note", id: world[:note].id, source_tag: "notes_box", followup_from_todays_notes: "true" } },
      "note/all" => -> { { class_name: "Note", id: world[:note].id, source_tag: "notes_box" } },
      "journal_followup/journal_id" => -> { { class_name: "JournalFollowup", journal_id: world[:journal].id, source_tag: "ai_assistant" } },
      "journal_followup/id" => -> { { class_name: "JournalFollowup", id: world[:journal].id, source_tag: "ai_assistant" } },
      "journal_followup/group_mate_journal" => -> { { class_name: "JournalFollowup", journal_id: world[:mate_journal].id, source_tag: "ai_assistant" } },
      "followup" => -> { { class_name: "Followup", id: world[:parent_followup].id, source_tag: "ai_assistant" } },
      "blank_class" => -> { { id: world[:entry].id, source_tag: "ai_assistant" } },
      "blank_id" => -> { { class_name: "Entry", source_tag: "ai_assistant" } },
      "unknown_class" => -> { { class_name: "User", id: world[:me].id } },
      "other_group_entry" => -> { { class_name: "Entry", id: world[:outsider_entry].id } }
    }.each do |name, params|
      it name do
        error = observing { get new_followup_path(instance_exec(&params)) }

        snapshot.match(self, "new/#{name}", error || page_observation)
      end
    end
  end

  describe "POST create" do
    let(:jobs) { [] }

    before do
      allow(FollowupRequestJob).to receive(:perform_later) { |*args| jobs << args }
    end

    def create_params(origin_class:, origin_id: nil, journal_id: nil, base: "What does this mean?", reference: "参考", tag: "ai_assistant")
      {
        followup: {
          source_tag: tag, followup_origin_class: origin_class, followup_origin_id: origin_id, journal_id: journal_id,
          followup_prompt: { base_content: base, user_generated_content: reference, ai_model: "grok-4-fast-non-reasoning", uuid: "uuid-1" }
        }
      }.deep_merge(followup: {}).tap { |h| h[:followup].compact! }
    end

    def create_observation
      prompt = FreeQuestionPrompt.order(:id).last if FreeQuestionPrompt.count > @prompts_before
      followup = prompt&.followup
      {
        page: page_observation.slice(:status, :location, :journal, :followup_origin),
        prompts_created: FreeQuestionPrompt.count - @prompts_before,
        journal_followups_created: JournalFollowup.count - @journal_followups_before,
        templates: FollowupTemplatePrompt.order(:id).pluck(:base_content),
        prompt: prompt && prompt.slice(:raw_prompt, :base_content, :user_generated_content, :ai_model, :uuid, :sent_role_prompt)
                              .merge(template: prompt.followup_template_prompt&.base_content),
        followup: followup && { origin: label(followup.origin), source_tag: followup.source_tag },
        jobs: jobs.map { |args| args.map { |arg| arg.is_a?(ActiveRecord::Base) ? label(arg) : arg } }
      }
    end

    {
      "entry" => -> { create_params(origin_class: "Entry", origin_id: world[:entry].id) },
      "ai_output/change" => -> { create_params(origin_class: "AiOutput", origin_id: world[:change_output].id) },
      "ai_output/quiz_assessment_due_notes" => -> {
        create_params(origin_class: "AiOutput", origin_id: world[:assessment].id, base: I18n.t("prompt_templates.due_notes_short"))
      },
      "note" => -> { create_params(origin_class: "Note", origin_id: world[:note].id, tag: "notes_box") },
      "note/due_notes_label_not_expanded" => -> {
        create_params(origin_class: "Note", origin_id: world[:note].id, tag: "notes_box", base: I18n.t("prompt_templates.due_notes_short"))
      },
      "journal_followup/new" => -> { create_params(origin_class: "JournalFollowup", journal_id: world[:mate_journal].id) },
      "journal_followup/existing" => -> { create_params(origin_class: "JournalFollowup", journal_id: world[:journal].id) },
      "journal_followup/due_notes" => -> {
        create_params(origin_class: "JournalFollowup", journal_id: world[:journal].id, base: I18n.t("prompt_templates.due_notes_short"))
      },
      "followup" => -> { create_params(origin_class: "Followup", origin_id: world[:parent_followup].id) },
      "unknown_sentinel" => -> { create_params(origin_class: "Unknown", origin_id: 0) },
      "zero_sentinel" => -> { create_params(origin_class: "0", origin_id: 0) },
      "blank_class" => -> { create_params(origin_class: "", origin_id: world[:entry].id) },
      "not_allowed_class" => -> { create_params(origin_class: "User", origin_id: world[:me].id) },
      "other_group_entry" => -> { create_params(origin_class: "Entry", origin_id: world[:outsider_entry].id) }
    }.each do |name, params|
      [ [ "html", {} ], [ "turbo", turbo ] ].each do |format, headers|
        it "#{name} (#{format})" do
          @prompts_before = FreeQuestionPrompt.count
          @journal_followups_before = JournalFollowup.count

          post followups_path, params: instance_exec(&params), headers: headers

          snapshot.match(self, "create/#{name}/#{format}", create_observation)
        end
      end
    end

    it "save_as_template (turbo)" do
      @prompts_before = FreeQuestionPrompt.count
      @journal_followups_before = JournalFollowup.count

      post followups_path,
           params: create_params(origin_class: "Entry", origin_id: world[:entry].id, base: "  Give me a mnemonic.  ").merge(save_as_template: "1"),
           headers: turbo

      snapshot.match(self, "create/save_as_template/turbo", create_observation)
    end
  end

  describe "GET show and DELETE destroy" do
    def followup_on(origin, tag = "ai_assistant")
      prompt = FreeQuestionPrompt.create!(raw_prompt: "x", ai_model: "m", uuid: SecureRandom.uuid, sent_role_prompt: "r")
      AiQuery.create!(journal: origin.try(:journal), prompt: prompt, raw_response: { "answer_1" => { "content" => "A", "explanation_en" => "E" } }.to_json)
      Followup.create!(prompt: prompt, origin: origin, source_tag: tag)
    end

    %i[entry change_output assessment note journal_followup].each do |origin_name|
      it "show for a #{origin_name} origin" do
        followup = followup_on(world[origin_name])

        # The show template raises today, so read the ivars the action set
        # before rendering.
        seen = {}
        allow_any_instance_of(FollowupsController).to receive(:show).and_wrap_original do |action|
          action.call
          seen = %i[journal followup_origin user source_tag].to_h { |name| [ name, action.receiver.instance_variable_get("@#{name}") ] }
        end

        error = observing { get followup_path(followup, source_tag: "ai_assistant") }

        snapshot.match(self, "show/#{origin_name}", {
          error: error,
          journal: label(seen[:journal]),
          followup_origin: label(seen[:followup_origin]),
          user: label(seen[:user]),
          source_tag: seen[:source_tag],
          followup_user: label(followup.user)
        })
      end

      [ [ "html", {} ], [ "turbo", turbo ] ].each do |format, headers|
        it "destroy for a #{origin_name} origin (#{format})" do
          followup = followup_on(world[origin_name])

          delete followup_path(followup, source_tag: "notes_box"), headers: headers

          snapshot.match(self, "destroy/#{origin_name}/#{format}", {
            status: response.status, location: normalize(response.location),
            display_frames: controller.instance_variable_get(:@display_frames),
            followup_gone: !Followup.exists?(followup.id)
          })
        end
      end
    end

    it "destroy with a journal param and display frame" do
      followup = followup_on(world[:entry])

      delete followup_path(followup, journal: world[:journal].id, source_tag: "ai_assistant", display_frame: "custom_frame")

      snapshot.match(self, "destroy/journal_param", {
        status: response.status, location: normalize(response.location),
        display_frames: controller.instance_variable_get(:@display_frames)
      })
    end
  end
end
