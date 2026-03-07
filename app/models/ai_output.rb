class AiOutput < ApplicationRecord
  include SharedMethods
  belongs_to :ai_query
  has_and_belongs_to_many :followups
  has_many :origin_followups, class_name: "Followup", as: :origin, dependent: :nullify
  delegate :journal, to: :ai_query, allow_nil: true
  has_many :quiz_answers, dependent: :destroy

  validates :identifier, presence: true # string
  validates :content, presence: true # text
  validates :made_note, inclusion: { in: [ true, false ] }

  def assemble_content(change_keyword, user)
    parsed = ai_query.parsed_response
    corrected_sentence = ai_query.corrected_text if parsed.keys.include?("corrected_text")
    assessment = ai_query.assessment if parsed.keys.include?("assessment")
    abbr = ai_query.abbr(user)
    learning_language = ai_query.prompt.learning_language

    if used_for_journal_corrected_text?
      assemble_corrected_text(corrected_sentence, learning_language)

    elsif used_to_grade_a_quiz?
      assemble_graded_quiz_assessment(assessment)

    elsif used_on_a_followup?(change_keyword)
      assemble_followup_content(abbr, change_keyword)

    else # When used on an AiOutput
      assemble_ai_output_content(abbr, change_keyword, corrected_sentence)
    end
  end

  private

  def used_for_journal_corrected_text?
    self.identifier == "corrected_text"
  end

  def used_to_grade_a_quiz?
    self.identifier == "assessment"
  end

  def assemble_ai_output_content(abbr, change_keyword, corrected_sentence)
    content = ai_query.change_content(self.identifier, change_keyword)
    content_first = content.first
    content_last = content.last
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
