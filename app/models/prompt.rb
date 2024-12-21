class Prompt < ApplicationRecord
  belongs_to :ai_query, optional: true
  # belongs_to :commit, optional: true
  belongs_to :followup, optional: true

  delegate :user, to: :ai_query, allow_nil: true

  validates :raw_prompt, presence: true
  validates :ai_model, presence: true
  validates :uuid, presence: true

  # When you're using single-table inheritance with your models, you can't rely on record identification on a subclass if only their parent class is declared a resource. You will have to specify :url, and :scope (the model name) explicitly.
end
