class AiQuery < ApplicationRecord
  belongs_to :commit, optional: true
  belongs_to :followup, optional: true
  has_one :prompt

  validates :prompt_tokens, :completion_tokens, :total_tokens, numericality: { only_integer: true }
  validates :type, presence: true
  validates :raw_response, presence: true
end
