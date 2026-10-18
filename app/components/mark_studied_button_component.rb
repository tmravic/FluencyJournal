class MarkStudiedButtonComponent < ApplicationComponent
  def initialize(journal:, from_all_or_todays: nil)
    @journal = journal
    @from_all_or_todays = from_all_or_todays.presence
  end
end
