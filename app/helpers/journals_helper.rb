module JournalsHelper
  def all_journals_empty?
    @from_all_or_todays == "all" && @all_journals.empty?
  end

  def todays_journals_empty?
    @from_all_or_todays == "todays" && @todays_journals.empty?
  end

  # After mark-as-studied: show today's empty state once nothing is due.
  # All Journals still lists the journal, so it never gets it.
  def todays_journals_empty_after_study?
    @from_all_or_todays != "all" && @due_today.zero?
  end
end
