class Followup < ApplicationRecord
  belongs_to :commit
  has_one :prompt
  has_one :ai_queries
end
