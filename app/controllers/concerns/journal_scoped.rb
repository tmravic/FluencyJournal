# frozen_string_literal: true

# For controllers nested under /journals/:journal_id. Loads @journal from
# the current group's journals before every action (404 otherwise).
module JournalScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_journal
  end

  private

  def set_journal
    @journal = current_group.journals.find(params.expect(:journal_id))
  end
end
