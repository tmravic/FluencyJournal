class Prompt < ApplicationRecord
  include NativeJapaneseGuidance

  # Chat explanation keys and xAI text-to-speech share these codes.
  # Older cards stored explanation_jp; AiQuery still reads that key.
  LANGUAGE_ABBREVIATIONS = { "English" => "en", "Japanese" => "ja" }.freeze

  has_one :ai_query, dependent: :destroy
  delegate :user, to: :ai_query, allow_nil: true
  has_one :followup, dependent: :destroy
  belongs_to :followup_template_prompt, optional: true
  accepts_nested_attributes_for :followup

  validates :raw_prompt, presence: true
  validates :ai_model, presence: true
  validates :uuid, presence: true
  validates :sent_role_prompt, presence: true

  # When you're using single-table inheritance with your models,
  # you can't rely on record identification on a subclass if
  # only their parent class is declared a resource.
  # You will have to specify :url, and :scope (the model name) explicitly.

  def self.language_code(language, default: "en")
    LANGUAGE_ABBREVIATIONS.fetch(language.to_s, default)
  end

  def self.abbr(user)
    language_code(user&.original_language)
  end

  def abbr(user)
    self.class.abbr(user)
  end

  def role_prompt(_user, _journal)
    raise NotImplementedError, "#{self.class}#role_prompt"
  end

  def response_format(_user, _journal, _quiz)
    raise NotImplementedError, "#{self.class}#response_format"
  end
end
