class NotesFollowup < ApplicationRecord
  belongs_to :note
  belongs_to :followup
end
