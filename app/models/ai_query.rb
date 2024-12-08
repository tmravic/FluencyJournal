class AiQuery < ApplicationRecord
  belongs_to :commit, optional: true
  belongs_to :followup, optional: true

  validates :prompt_tokens, :completion_tokens, :total_tokens, numericality: { only_integer: true }
  validates :type, presence: true
end
