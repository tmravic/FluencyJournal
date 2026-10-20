class AiOutput < ApplicationRecord
  include SharedMethods
  belongs_to :ai_query
  has_many :followups, as: :origin, dependent: :nullify
  delegate :journal, to: :ai_query, allow_nil: true
  has_many :quiz_answers, dependent: :destroy

  validates :identifier, presence: true # string
  validates :content, presence: true # text
  validates :made_note, inclusion: { in: [ true, false ] }

  # A line stores its entry position in identifier. corrected_text and
  # assessment keep those identifier strings so existing frame ids stay put.
  enum :role, {
    line: "line",
    corrected_text: "corrected_text",
    assessment: "assessment"
  }, default: "line", validate: true

  before_validation :assign_role_from_identifier

  def line_number
    assign_role_from_identifier
    identifier.to_i if line?
  end

  def assemble_content(change_keyword, user)
    assign_role_from_identifier
    parsed = ai_query.parsed_response
    parsed = {} unless parsed.is_a?(Hash)
    corrected_sentence = ai_query.corrected_text if ai_query.corrected_text_key?
    assessment = ai_query.assessment if parsed.key?("assessment")
    abbr = ai_query.abbr(user) if user
    learning_language = ai_query.prompt&.user_generated_content

    if corrected_text?
      assemble_corrected_text(corrected_sentence, learning_language)

    elsif assessment?
      assemble_graded_quiz_assessment(assessment)

    elsif used_on_a_followup?(change_keyword)
      assemble_followup_content(abbr, change_keyword)

    else # When used on an AiOutput
      assemble_ai_output_content(abbr, change_keyword, corrected_sentence)
    end
  end

  # Persists the card when there is something to show. A blank change line
  # returns nil from assemble_content. Saving that would fail the job before
  # the corrected sentence is stored, and leaving the unsaved build on the
  # query would look like a card that never made it to the database.
  def save_assembled_content(change_keyword, user)
    assembled = assemble_content(change_keyword, user)
    if assembled.blank?
      ai_query.ai_outputs.target.delete(self) if new_record? && ai_query
      return
    end

    self.content = assembled
    save!
  end

  private

  def assign_role_from_identifier
    return unless line?

    self.role = identifier if identifier.in?(%w[corrected_text assessment])
  end

  def assemble_ai_output_content(abbr, change_keyword, corrected_sentence)
    content_first, content_last = ai_query.change_sides(self.identifier, change_keyword)
    return if content_first.blank? && content_last.blank?

    explanation = ai_query.change_explanation(change_keyword, self.identifier, abbr)

    # Ex:
    # お寺でキラキラした10円玉を賽銭箱に投入しました。
    # (Changed the form of the adjective to past tense to match the completed action.)
    # キラキラしてる
    # ↓
    # キラキラした
    "#{corrected_sentence}\n(#{explanation})\n#{content_first}\n↓\n#{content_last}"
  end

  def assemble_followup_content(abbr, change_keyword)
    content = ai_query.change_content(self.identifier, change_keyword)
    return if content.blank?

    explanation = ai_query.change_explanation(change_keyword, self.identifier, abbr)

    # Ex:
    # 願い (ねが)い
    # (The reading for the kanji 願 is ねがい, which means 'wish' or 'request'.)
    "#{content}\n(#{explanation})"
  end

  def assemble_graded_quiz_assessment(assessment)
    assessment || ai_query.error_message
  end

  def assemble_corrected_text(corrected_sentence, learning_language)
    return if corrected_sentence.blank?

    # Ex:
    # お寺でキラキラしてる10円玉を賽銭箱に投入しました。
    # ↓
    # お寺でキラキラした10円玉を賽銭箱に投入しました。
    "#{learning_language}\n↓\n#{corrected_sentence}"
  end

  def used_on_a_followup?(change_keyword)
    ai_query.change_content(self.identifier, change_keyword).is_a?(String)
  end
end
