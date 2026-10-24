# Base class for the buttons that only need the journal they act on.
# Subclasses add their own template (and extra arguments if any).
class JournalButtonComponent < ApplicationComponent
  def initialize(journal:)
    @journal = journal
  end
end
