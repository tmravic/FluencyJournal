require "rails_helper"
require_relative "../support/characterization_snapshot"

# Pins the quiz pages and member actions before K6 moves the association
# chains into Quiz. Bodies are stored with record ids replaced by labels.
# GradeQuizJob is stubbed; nothing is sent to the model.
RSpec.describe "Quizzes (characterization)", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  snapshot = CharacterizationSnapshot.new("quizzes")
  turbo = { "Accept" => "text/vnd.turbo-stream.html" }

  before { travel_to Time.zone.local(2026, 3, 10, 9, 0, 0) }
  after { travel_back }

  def prompt!(klass, raw)
    klass.create!(raw_prompt: raw, ai_model: "grok-4-fast-non-reasoning", uuid: SecureRandom.uuid, sent_role_prompt: "role")
  end

  let!(:world) do
    group = Group.create!(name: "QC #{SecureRandom.hex(4)}")
    me = User.create!(email_address: "qc-#{SecureRandom.hex(4)}@example.com", password: "password",
                      original_language: "English", learning_language: "Japanese", group: group)
    journal = Journal.create!(title: "Quiz journal", user: me, group: group, last_interval: 1)
    first = journal.entries.create!(content: "彼女のお母さんに会いました。")
    journal.entries.create!(content: "三人でピザを食べました。")

    prepare = AiQuery.create!(journal: journal, prompt: prompt!(PrepareQuizPrompt, "prepare"),
                              raw_response: { "line_1" => { "translation" => "I met her mother." },
                                              "line_2" => { "translation" => "We ate pizza." } }.to_json)
    q1 = prepare.ai_outputs.create!(identifier: "1", content: "I met her mother.", made_note: false)
    q2 = prepare.ai_outputs.create!(identifier: "2", content: "We ate pizza.", made_note: false)
    extra = prepare.ai_outputs.create!(identifier: "assessment", content: "Not a question", made_note: false)
    quiz = Quiz.create!(journal: journal, ai_query: prepare)
    QuizHint.create!(quiz: quiz, entry: first, ai_query: prepare, hint_content: "Think of 会う")
    quiz.quiz_answers.create!(ai_output: q1, user_response: "彼女のお母さんに会った。")

    graded_prepare = AiQuery.create!(journal: journal, prompt: prompt!(PrepareQuizPrompt, "prepare 2"), raw_response: "{}")
    gq1 = graded_prepare.ai_outputs.create!(identifier: "1", content: "Graded question", made_note: false)
    grading = AiQuery.create!(journal: journal, prompt: prompt!(QuizResultPrompt, "grade"),
                              raw_response: { "entry_1" => { "content" => "会った → 会いました", "explanation_en" => "Polite." },
                                              "assessment" => "Good work." }.to_json)
    grading.ai_outputs.create!(identifier: "1", content: "会った\n↓\n会いました", made_note: false, role: :line)
    grading.ai_outputs.create!(identifier: "assessment", content: "Good work.", made_note: false, role: :assessment)
    graded = Quiz.create!(journal: journal, ai_query: graded_prepare, grading_ai_query: grading)
    graded.quiz_answers.create!(ai_output: gq1, user_response: "会った")

    labels = { journal.id => "JOURNAL", quiz.id => "QUIZ", graded.id => "GRADED", q1.id => "Q1", q2.id => "Q2",
               extra.id => "EXTRA", gq1.id => "GQ1", prepare.id => "PREPARE", graded_prepare.id => "GPREPARE",
               grading.id => "GRADING" }
    { me: me, journal: journal, quiz: quiz, graded: graded, q1: q1, q2: q2, extra: extra, labels: labels }
  end

  # Ids are database sequence values well above any year or time in the
  # frozen dates, so whole-number matches are safe.
  def normalize(text)
    text = text.dup
    labels = world[:labels]
    labels = labels.merge(AiOutput.where.not(id: labels.keys).pluck(:id).index_with { "OUT_NEW" })
    labels = labels.merge(QuizAnswer.pluck(:id).index_with { "ANSWER" })
    labels = labels.merge(world[:journal].entries.pluck(:id, :position).to_h { |id, pos| [ id, "ENTRY#{pos}" ] })
    labels.sort_by { |id, _| -id.to_s.length }.each do |id, label|
      text.gsub!(/(?<!\d)#{id}(?!\d)/, label)
    end
    text.gsub!(/(name="authenticity_token" value=")[^"]*/, '\1TOKEN')
    text.gsub!(/(name="csrf-token" content=")[^"]*/, '\1TOKEN')
    text.gsub!(/(signed-stream-name=")[^"]*/, '\1SIGNED')
    text.gsub!(/\b(qc|Qc)-\h{8}/, '\1-USER')
    text.gsub!(/\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/, "UUID")
    text
  end

  def body_lines
    body = response.body
    if response.status >= 400
      heading = body[%r{<h1>(.*?)</h1>}m, 1].to_s
      message = body[%r{<div class="exception-message">\s*<div[^>]*>(.*?)</div>}m, 1].to_s
      return [ heading, message ].map { |part| normalize(CGI.unescapeHTML(part.gsub(/<[^>]+>/, "")).squish) }
    end

    normalize(body.split("<body>", 2).last.to_s).lines.map(&:rstrip).reject(&:empty?)
  end

  def observe(key, snapshot, example, extra = {})
    snapshot.match(example, key, { "status" => response.status,
                                   "location" => response.location&.then { |l| normalize(l) },
                                   "body" => body_lines }.merge(extra))
  end

  before { post session_path, params: { email_address: world[:me].email_address, password: "password" } }

  it("shows an ungraded quiz") { get journal_quiz_path(world[:journal], world[:quiz]); observe("show/ungraded", snapshot, self) }
  it("shows a graded quiz") { get journal_quiz_path(world[:journal], world[:graded]); observe("show/graded", snapshot, self) }

  %w[peek unpeek show_hint hide_hint show_original_language hide_original_language].each do |action|
    %i[q1 q2 extra].each do |output|
      it "answers #{action} for #{output}" do
        get public_send("#{action}_journal_quiz_path", world[:journal], world[:quiz], ai_output_id: world[output].id),
            headers: turbo
        observe("#{action}/#{output}", snapshot, self)
      end
    end
  end

  it "answers 404 for an output of another quiz" do
    get peek_journal_quiz_path(world[:journal], world[:quiz], ai_output_id: world[:labels].key("GQ1")), headers: turbo
    observe("peek/other_quiz_output", snapshot, self)
  end

  %i[q2 extra].each do |output|
    it "answers #{output} through quiz_answers#create" do
      post journal_quiz_quiz_answers_path(world[:journal], world[:quiz]),
           params: { quiz_answer: { ai_output_id: world[output].id, user_response: "We ate pizza." } }, headers: turbo
      observe("answer/#{output}", snapshot, self)
    end
  end

  it "grades a quiz with the questions and answers in the prompt" do
    allow(GradeQuizJob).to receive(:perform_later)
    post grade_quiz_journal_quiz_path(world[:journal], world[:quiz]), headers: turbo
    prompt = QuizResultPrompt.order(:id).last
    observe("grade_quiz", snapshot, self,
            "prompt" => prompt.attributes.slice("raw_prompt", "base_content", "user_generated_content", "sent_role_prompt"))
    expect(GradeQuizJob).to have_received(:perform_later).with(world[:journal], prompt, world[:quiz])
  end
end
