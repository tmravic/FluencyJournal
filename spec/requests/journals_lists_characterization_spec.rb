require "rails_helper"
require_relative "../support/characterization_snapshot"

# Pins the journal lists (index = today's, all) and the actions that
# re-render the list they came from (destroy, mark studied) before C14
# gives the lists one lookup table. Bodies are stored with record ids
# replaced by labels and per-request tokens removed.
RSpec.describe "Journal lists (characterization)", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  snapshot = CharacterizationSnapshot.new("journals_lists")
  turbo = { "Accept" => "text/vnd.turbo-stream.html" }

  before { travel_to Time.zone.local(2026, 3, 10, 9, 0, 0) }
  after { travel_back }

  let!(:world) do
    group = Group.create!(name: "JL #{SecureRandom.hex(4)}")
    me = User.create!(email_address: "jl-#{SecureRandom.hex(4)}@example.com", password: "password",
                      original_language: "English", learning_language: "Japanese", group: group)
    due = Journal.create!(title: "B due", user: me, group: group, last_interval: 1, next_study_date: 1.day.ago)
    other_due = Journal.create!(title: "A due", user: me, group: group, last_interval: 1, next_study_date: 2.days.ago)
    later = Journal.create!(title: "C later", user: me, group: group, last_interval: 1, next_study_date: 3.days.from_now)
    done = Journal.create!(title: "D done", user: me, group: group, last_interval: 1,
                           next_study_date: 2.days.from_now, last_studied_at: 1.hour.ago)
    labels = { due.id => "J_DUE", other_due.id => "J_OTHER_DUE", later.id => "J_LATER", done.id => "J_DONE" }
    { me: me, due: due, other_due: other_due, later: later, labels: labels }
  end

  def normalize(text)
    text = text.dup
    world[:labels].sort_by { |id, _| -id.to_s.length }.each do |id, label|
      text.gsub!(/(?<![\d\-:.])#{id}(?![\d\-:.])/, label)
    end
    text.gsub!(/(name="authenticity_token" value=")[^"]*/, '\1TOKEN')
    text.gsub!(/(name="csrf-token" content=")[^"]*/, '\1TOKEN')
    text.gsub!(/(signed-stream-name=")[^"]*/, '\1SIGNED')
    text.gsub!(/\b(jl|Jl)-\h{8}/, '\1-USER')
    text.gsub!(/\b(JL) \h{8}/, '\1 GROUP')
    text.gsub!(/\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/, "UUID")
    text
  end

  def body_lines
    body = response.body
    if response.status >= 400
      heading = body[%r{<h1>(.*?)</h1>}m, 1].to_s
      message = body[%r{<div class="exception-message">\s*<div[^>]*>(.*?)</div>}m, 1].to_s
      return [ heading, message ].map { |part| CGI.unescapeHTML(part.gsub(/<[^>]+>/, "")).squish }
    end

    normalize(body.split("<body>", 2).last.to_s).lines.map(&:rstrip).reject(&:empty?)
  end

  def observe(key, snapshot, example)
    snapshot.match(example, key, { "status" => response.status,
                                   "location" => response.location&.then { |l| normalize(l) },
                                   "body" => body_lines })
  end

  before { post session_path, params: { email_address: world[:me].email_address, password: "password" } }

  it("renders today's journals") { get journals_path; observe("list/index", snapshot, self) }
  it("renders all journals") { get all_journals_path; observe("list/all", snapshot, self) }

  [ "todays", "all", nil ].each do |list|
    it "destroys a journal from #{list.inspect} (turbo)" do
      delete journal_path(world[:due], from_all_or_todays: list), headers: turbo
      observe("destroy/#{list.inspect}/turbo", snapshot, self)
    end

    it "destroys a journal from #{list.inspect} (html)" do
      delete journal_path(world[:due], from_all_or_todays: list)
      observe("destroy/#{list.inspect}/html", snapshot, self)
    end

    it "marks a journal studied from #{list.inspect} (turbo, nested param)" do
      post mark_journal_as_studied_journal_path(world[:due]), params: { journal: { from_all_or_todays: list } },
                                                              headers: turbo
      observe("mark_studied/#{list.inspect}/nested", snapshot, self)
    end
  end

  [ "todays", "all" ].each do |list|
    it "destroys the last journal of #{list.inspect} and shows the empty state (turbo)" do
      keep = list == "todays" ? [ world[:later] ] : []
      Journal.where(group: world[:me].group).where.not(id: [ world[:due].id, *keep.map(&:id) ]).destroy_all
      delete journal_path(world[:due], from_all_or_todays: list), headers: turbo
      observe("destroy_last/#{list.inspect}/turbo", snapshot, self)
    end
  end
end
