class Prompt < ApplicationRecord

  LANGUAGE_ABBREVIATIONS = { "English" => "en", "Japanese" => "jp" }

  has_one :ai_query, dependent: :destroy
  delegate :user, to: :ai_query, allow_nil: true
  has_one :followup, dependent: :destroy
  accepts_nested_attributes_for :followup

  validates :raw_prompt, presence: true
  validates :ai_model, presence: true
  validates :uuid, presence: true
  validates :sent_role_prompt, presence: true
  validates :base_content, presence: false
  validates :user_generated_content, presence: true

  # When you're using single-table inheritance with your models,
  # you can't rely on record identification on a subclass if
  # only their parent class is declared a resource.
  # You will have to specify :url, and :scope (the model name) explicitly.

  def abbr(user)
    LANGUAGE_ABBREVIATIONS.fetch(user.original_language, 'English')
  end

  def original_language
    base_content
  end

  def learning_language
    user_generated_content
  end
end
