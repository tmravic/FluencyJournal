class Followup < ApplicationRecord
  belongs_to :ai_queries
  has_one :notes_followups
  has_one :notes, through: :notes_followups
  has_one :entries_followups
  has_one :entry, through: :entries_followups
end
