class Prompt < ApplicationRecord
  belongs_to :ai_query, optional: true
  belongs_to :commit, optional: true
  belongs_to :followup, optional: true

  validates :raw_prompt, presence: true
  validates :ai_model, presence: true
  validates :uuid, presence: true


end
