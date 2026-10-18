class ReadingModeButtonComponent < ApplicationComponent
  def initialize(journal:, reading_mode:)
    @journal = journal
    @reading_mode = !!reading_mode
  end
end
