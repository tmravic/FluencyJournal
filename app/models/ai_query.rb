class AiQuery < ApplicationRecord
  belongs_to :entry, optional: true
  belongs_to :followup, optional: true
  has_one :prompt, dependent: :destroy
  delegate :user, to: :entry, allow_nil: true

  validates :prompt_tokens, :completion_tokens, :total_tokens, numericality: { only_integer: true }
  validates :type, presence: true
  validates :raw_response, presence: true

  # When you're using single-table inheritance with your models, you can't rely on record identification on a subclass if only their parent class is declared a resource. You will have to specify :url, and :scope (the model name) explicitly.
end
