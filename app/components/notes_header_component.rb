class NotesHeaderComponent < ApplicationComponent
  LISTS = %w[todays_notes all_notes draft_notes journal].freeze

  def initialize(list:, journal: nil)
    @list = list.to_s
    raise ArgumentError, "unknown notes list: #{@list}" unless LISTS.include?(@list)
    raise ArgumentError, "journal is required for the journal notes list" if @list == "journal" && journal.nil?

    @journal = journal
  end

  def todays?
    @list == "todays_notes"
  end

  def all?
    @list == "all_notes"
  end

  def drafts?
    @list == "draft_notes"
  end

  def journal_list?
    @list == "journal"
  end
end
