class Followup < ApplicationRecord
  belongs_to :entry
  has_one :prompt
  has_one :ai_queries
end
