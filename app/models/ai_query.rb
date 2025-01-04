class AiQuery < ApplicationRecord
  LANGUAGE_ABBREVIATIONS = { "English" => "en", "Japanese" => "jp" }

  belongs_to :journal, optional: true
  has_one :prompt, dependent: :destroy
  delegate :user, to: :journal, allow_nil: true

  validates :prompt_tokens, :completion_tokens, :total_tokens, numericality: { only_integer: true }
  validates :type, presence: true
  validates :raw_response, presence: true
  # validates :made_note　<-- boolean

  def abbr(user)
    # This same thing exists on Prompt
    LANGUAGE_ABBREVIATIONS.fetch(user.original_language, 'English')
  end
end
