# One request to the model. A prompt owns what came of it: its answer
# query (AiQuery) and, for followup questions, its Followup.
#
# Deleting works from either end, and the whole group always goes:
#   - prompt.destroy      -> destroys its ai_query and followup
#                            (dependent: :destroy below);
#   - ai_query.destroy or
#     followup.destroy    -> their after_destroy calls Prompt.destroy_from,
#                            which destroys the prompt, and with it the
#                            other child.
# destroy_from skips the call when the prompt itself is the one deleting
# the child, so the two paths never loop.
class Prompt < ApplicationRecord
  include NativeJapaneseGuidance

  # Chat explanation keys and xAI text-to-speech share these codes.
  # Older cards stored explanation_jp; AiQuery still reads that key.
  LANGUAGE_ABBREVIATIONS = { "English" => "en", "Japanese" => "ja" }.freeze

  has_one :ai_query, dependent: :destroy
  delegate :user, to: :ai_query, allow_nil: true
  has_one :followup, dependent: :destroy

  # The prompt owns the followup and the answer query. A child calls this
  # after its own row is gone. Skip when this prompt is already destroying
  # that child, so the two deletes do not call each other.
  def self.destroy_from(child)
    return if child.destroyed_by_association&.active_record == self

    prompt = child.prompt
    return if prompt.nil? || prompt.destroyed?

    prompt.association(:followup).reset
    prompt.association(:ai_query).reset
    prompt.destroy!
  end

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

  # The code of the language explanations are written in: the reader's
  # original language ("en", "ja"), used in explanation_<code> keys.
  def self.explanation_language_code(user)
    language_code(user&.original_language)
  end

  def explanation_language_code(user)
    self.class.explanation_language_code(user)
  end

  # The contract every prompt type fulfils:
  # - role_prompt(user, journal): the system/role text sent to the model;
  # - response_format(user, journal, quiz): the JSON shape it must answer in;
  # - item_prefix / change_keyword: the key prefix of the numbered items in
  #   that answer ("change_1", "answer_2", ...).
  # Retired prompt rows (the old hint prompt, stored as the base class) have
  # no item prefix and are not listable.
  class_attribute :item_prefix, instance_writer: false, default: nil

  def change_keyword
    item_prefix || raise(NotImplementedError, "#{self.class}#change_keyword")
  end

  # True for prompt types whose answers are shown as numbered items.
  def listable?
    item_prefix.present?
  end

  def role_prompt(_user, _journal)
    raise NotImplementedError, "#{self.class}#role_prompt"
  end

  def response_format(_user, _journal, _quiz)
    raise NotImplementedError, "#{self.class}#response_format"
  end

  private

  # The example answer shape shown to the model, e.g. for EntryPrompt:
  #   { { change_1: { ... }, change_2: { ... }, change_3: { ... }, ...,corrected_text: { '...' } } }
  # It is not strict JSON; the wording is part of what the model has always
  # been sent, so keep it byte-for-byte (see prompt_text_characterization_spec).
  def example_answer(count, item, extra: nil)
    body = (1..count).map { |n| "#{item_prefix}#{n}: { #{item} }" }.join(", ")
    body += ", ...,#{extra}" if extra
    "{ { #{body} } }"
  end

  # A "before → after" item with an explanation in the reader's language.
  def correction_item(user)
    "content: '... → ...', explanation_#{explanation_language_code(user)}: '...'"
  end

  # Role prompts keep their static wording in a heredoc template. The
  # template is squished first and the user's values are inserted after, so
  # their text (journal entries, language names) is never re-spaced. The
  # trailing space separates the text from any guidance appended after it.
  def fill(template, user, **values)
    format(template.squish, learning: user.learning_language, original: user.original_language, **values) + " "
  end

  # Earlier entries of the journal, as context the model must not correct.
  def journal_context(journal)
    "Each item in this array is part of a previous entry in this journal, which you " \
      "should not correct or comment on but refer to as context to understand the current entry: " \
      "#{json_list(journal.full_journal)}. "
  end

  # Lists sent to the model are JSON arrays, not Ruby's Array#to_s output.
  def json_list(values)
    JSON.generate(Array(values))
  end
end
