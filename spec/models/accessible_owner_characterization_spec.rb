require "rails_helper"
require_relative "../support/characterization_snapshot"

# Pins which records AccessibleOwner lets a user reach, for every finder,
# before K5 replaces its type chains. Records: mine, a group-mate's, an
# outsider's (other group), plus note-followup queries with no journal.
RSpec.describe AccessibleOwner, "(characterization)", type: :model do
  snapshot = CharacterizationSnapshot.new("accessible_owner")

  let(:finder_class) do
    Class.new do
      include AccessibleOwner
      public(*AccessibleOwner.private_instance_methods)
      attr_accessor :current_group
    end
  end

  def make_user(group, label)
    User.create!(email_address: "ao-#{label}-#{SecureRandom.hex(4)}@example.com", password: "password",
                 original_language: "English", learning_language: "Japanese", group: group)
  end

  def prompt(klass = FreeQuestionPrompt)
    klass.create!(raw_prompt: "x", ai_model: Prompt::DEFAULT_MODEL, uuid: SecureRandom.uuid, sent_role_prompt: "r")
  end

  # Builds the same graph for one owner and returns labelled records.
  def graph_for(user, group, tag)
    journal = Journal.create!(title: "#{tag} journal", user: user, group: group, last_interval: 1)
    entry = journal.entries.create!(content: "#{tag} entry")
    note = user.notes.create!(content: "#{tag} note")
    journal_followup = journal.journal_followups.create!
    query = AiQuery.create!(journal: journal, prompt: prompt(EntryPrompt), raw_response: "{}")
    output = query.ai_outputs.create!(identifier: "1", content: "c", made_note: false)
    note_prompt = prompt
    Followup.create!(prompt: note_prompt, origin: note, source_tag: "notes_box")
    note_query = AiQuery.create!(journal: nil, prompt: note_prompt, raw_response: "{}")
    note_output = note_query.ai_outputs.create!(identifier: "1", content: "c", made_note: false)
    entry_followup = Followup.create!(prompt: prompt, origin: entry, source_tag: "ai_assistant")
    {
      "#{tag}_entry" => entry, "#{tag}_note" => note, "#{tag}_journal_followup" => journal_followup,
      "#{tag}_query" => query, "#{tag}_output" => output, "#{tag}_note_query" => note_query,
      "#{tag}_note_output" => note_output, "#{tag}_entry_followup" => entry_followup,
      "#{tag}_note_followup" => note_prompt.followup,
      "#{tag}_output_followup" => Followup.create!(prompt: prompt, origin: output, source_tag: "ai_assistant"),
      "#{tag}_journal_followup_followup" => Followup.create!(prompt: prompt, origin: journal_followup, source_tag: "ai_assistant"),
      "#{tag}_followup_followup" => Followup.create!(prompt: prompt, origin: entry_followup, source_tag: "ai_assistant"),
      "#{tag}_orphan_followup" => Followup.create!(prompt: prompt, origin: nil, source_tag: "ai_assistant")
    }
  end

  def reachable?
    yield
    true
  rescue ActiveRecord::RecordNotFound
    false
  end

  it "reaches the same records through every finder" do
    group = Group.create!(name: "AO #{SecureRandom.hex(4)}")
    other = Group.create!(name: "AO other #{SecureRandom.hex(4)}")
    me = make_user(group, "me")
    records = graph_for(me, group, "mine")
      .merge(graph_for(make_user(group, "mate"), group, "mate"))
      .merge(graph_for(make_user(other, "outsider"), other, "outsider"))

    finder = finder_class.new
    finder.current_group = group
    allow(Current).to receive(:user).and_return(me)

    observation = {}
    { Entry => :find_accessible_entry, Note => :find_accessible_note, JournalFollowup => :find_accessible_journal_followup,
      AiQuery => :find_accessible_ai_query, AiOutput => :find_accessible_ai_output, Followup => :find_accessible_followup }
      .each do |klass, finder_method|
        candidates = records.select { |_label, record| record.is_a?(klass) }
        observation[finder_method] = candidates.filter_map do |label, record|
          label if reachable? { finder.public_send(finder_method, record.id) }
        end.sort
        observation["find_accessible_origin(#{klass})"] = candidates.filter_map do |label, record|
          label if reachable? { finder.find_accessible_origin(klass, record.id) }
        end.sort
      end
    observation["find_accessible_origin(User)"] = reachable? { finder.find_accessible_origin(User, me.id) }

    snapshot.match(self, "reachable", observation)
  end
end
