require "rails_helper"
require_relative "../support/characterization_snapshot"

# Pins the note lists (index, all, drafts, for_journal) and the actions
# that re-render a list (create, update, destroy, the journal-link
# actions) before C6/C17 give the lists named scopes. Response bodies are
# stored with record ids replaced by labels and per-request tokens removed.
RSpec.describe "Note lists (characterization)", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  snapshot = CharacterizationSnapshot.new("notes_lists")
  turbo = { "Accept" => "text/vnd.turbo-stream.html" }

  before { travel_to Time.zone.local(2026, 3, 10, 9, 0, 0) }
  after { travel_back }

  let!(:world) do
    group = Group.create!(name: "NL #{SecureRandom.hex(4)}")
    me = User.create!(email_address: "nl-#{SecureRandom.hex(4)}@example.com", password: "password",
                      original_language: "English", learning_language: "Japanese", group: group)
    journal = Journal.create!(title: "Linked journal", user: me, group: group, last_interval: 1)
    due = me.notes.create!(content: "Due vocab", meaning: "m1", category: :vocab, next_study_date: 2.days.ago)
    later = me.notes.create!(content: "Later grammar", category: :grammar, next_study_date: 3.days.from_now)
    draft = me.notes.create!(content: "Draft note", category: :draft_journal, next_study_date: 1.day.ago)
    due.journals << journal
    prompt = FreeQuestionPrompt.create!(raw_prompt: "Followup Question: why?", ai_model: Prompt::DEFAULT_MODEL,
                                        uuid: SecureRandom.uuid, sent_role_prompt: "r")
    Followup.create!(prompt: prompt, origin: due, source_tag: "notes_box")
    labels = { journal.id => "J_LINKED", due.id => "N_DUE", later.id => "N_LATER", draft.id => "N_DRAFT" }
    { me: me, journal: journal, due: due, later: later, draft: draft, labels: labels }
  end

  def normalize(body)
    text = body.dup
    labels = world[:labels].merge(Note.where.not(id: world[:labels].keys).pluck(:id).index_with { "N_NEW" })
    labels = labels.merge(Followup.pluck(:id).index_with { |id| "F#{id == world[:due].followups.first&.id ? '_DUE' : '_NEW'}" })
    labels.sort_by { |id, _| -id.to_s.length }.each do |id, label|
      text.gsub!(/(?<![\d\-:.])#{id}(?![\d\-:.])/, label)
    end
    text.gsub!(/(name="authenticity_token" value=")[^"]*/, '\1TOKEN')
    text.gsub!(/(name="csrf-token" content=")[^"]*/, '\1TOKEN')
    text.gsub!(/\b(nl|Nl)-\h{8}/, '\1-USER')
    text.gsub!(/\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/, "UUID")
    text.gsub!(/assets\/([\w\-]+)-\h+\.(js|css)/, 'assets/\1-DIGEST.\2')
    text
  end

  # The page body after <body>, or for an error page only its heading.
  def body_lines
    body = response.body
    if response.status >= 400
      heading = body[%r{<h1>(.*?)</h1>}m, 1].to_s
      message = body[%r{<div class="exception-message">\s*<div[^>]*>(.*?)</div>}m, 1].to_s
      return [ heading, message ].map { |part| CGI.unescapeHTML(part.gsub(/<[^>]+>/, "")).squish }
    end

    body = body.split("<body>", 2).last
    normalize(body).lines.map(&:rstrip).reject(&:empty?)
  end

  def observe(example_key, snapshot, example)
    snapshot.match(example, example_key, { "status" => response.status,
                                          "location" => response.location&.then { |l| normalize(l) },
                                          "body" => body_lines })
  end

  before { post session_path, params: { email_address: world[:me].email_address, password: "password" } }

  { "index" => -> { notes_path }, "all" => -> { all_notes_path }, "drafts" => -> { drafts_notes_path },
    "for_journal" => -> { for_journal_notes_path(journal_id: world[:journal].id) } }.each do |name, path|
    %w[html turbo].each do |fmt|
      next if fmt == "turbo" && name == "for_journal"

      it "renders #{name} (#{fmt})" do
        get instance_exec(&path), headers: fmt == "turbo" ? turbo : {}
        observe("list/#{name}/#{fmt}", snapshot, self)
      end
    end
  end

  [ "todays_notes", "all_notes", "draft_notes", "journal", nil ].each do |view_context|
    it "creates a note from #{view_context.inspect} (turbo)" do
      post notes_path, params: { note: { content: "Brand new", category: "vocab" }, view_context: view_context },
                       headers: turbo
      observe("create/#{view_context.inspect}", snapshot, self)
    end
  end

  [ "true", "false" ].each do |from_todays|
    it "updates a note with update_from_todays_notes=#{from_todays} (turbo)" do
      patch note_path(world[:due]), params: { note: { content: "Due vocab edited" }, update_from_todays_notes: from_todays },
                                    headers: turbo
      observe("update/#{from_todays}", snapshot, self)
    end

    it "opens, cancels and saves the journal links with from_todays_notes=#{from_todays} (frame)" do
      frame = { "Turbo-Frame" => "note_#{world[:due].id}" }
      get link_journals_note_path(world[:due], from_todays_notes: from_todays), headers: frame
      observe("link_journals/#{from_todays}", snapshot, self)
      get cancel_link_journals_note_path(world[:due], from_todays_notes: from_todays), headers: frame
      observe("cancel_link_journals/#{from_todays}", snapshot, self)
      post update_journals_note_path(world[:due], from_todays_notes: from_todays),
           params: { note: { journal_ids: [ world[:journal].id ] } }, headers: frame
      observe("update_journals/#{from_todays}", snapshot, self)
    end

    it "destroys a note with delete_from_todays_notes=#{from_todays} (turbo)" do
      delete note_path(world[:later], delete_from_todays_notes: from_todays), headers: turbo
      observe("destroy/#{from_todays}", snapshot, self)
    end
  end
end
