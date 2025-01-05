class AiQuery < ApplicationRecord
  LANGUAGE_ABBREVIATIONS = { "English" => "en", "Japanese" => "jp" }

  belongs_to :journal, optional: true
  belongs_to :prompt
  delegate :user, to: :journal, allow_nil: true
  has_many :ai_outputs, dependent: :destroy
  has_many :followups#, dependent: :destroy

  validates :prompt_tokens, :completion_tokens, :total_tokens, numericality: { only_integer: true }
  validates :type, presence: true
  validates :raw_response, presence: true
  # validates :made_note　<-- Hash  ex: { 1 => false, 2 => false, 3 => false }

  def abbr(user)
    # This same thing exists on Prompt
    LANGUAGE_ABBREVIATIONS.fetch(user.original_language, 'English')
  end
end
