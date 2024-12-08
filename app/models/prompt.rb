class Prompt < ApplicationRecord
  belongs_to :ai_query
  belongs_to :commit, optional: true
  belongs_to :followup, optional: true

  validates :raw_prompt, presence: true
end
