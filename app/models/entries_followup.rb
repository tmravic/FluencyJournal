class EntriesFollowup < ApplicationRecord
  belongs_to :entry
  belongs_to :followup
end
