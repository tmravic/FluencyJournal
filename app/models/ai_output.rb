class AiOutput < ApplicationRecord
  belongs_to :ai_query
  has_and_belongs_to_many :followups
  has_many :origin_followups, class_name: "Followup", as: :origin, dependent: :nullify
  delegate :journal, to: :ai_query, allow_nil: true
  has_many :quiz_answers #, through: :ai_query

  validates :identifier, presence: true # string
  validates :content, presence: true # text
  validates :made_note, inclusion: { in: [ true, false ] }

  def assemble_content(change_keyword, user) # Shouldn't this be in a Helper?
    parsed = ai_query.parsed_response
    corrected_sentence = ai_query.corrected_text if parsed.keys.include?("corrected_text")
    assessment = ai_query.assessment if parsed.keys.include?("assessment")
    abbr = ai_query.abbr(user)
    learning_language = ai_query.prompt.learning_language

    if self.identifier == "corrected_text"
      # Ex:
      # お寺でキラキラしてる10円玉を賽銭箱に投入しました。
      # ↓
      # お寺でキラキラした10円玉を賽銭箱に投入しました。
      "#{learning_language}\n↓\n#{corrected_sentence}"
    elsif self.identifier == "assessment"
      # New: For a graded quiz assessment
      assessment || ai_query.error_message
    elsif ai_query.change_content(self.identifier, change_keyword).is_a?(String)
      # When used on a Followup
      content = ai_query.change_content(self.identifier, change_keyword)
      explanation = ai_query.change_explanation(change_keyword, self.identifier, abbr)

      # Ex:
      # 願い (ねが)い
      # (The reading for the kanji 願 is ねがい, which means 'wish' or 'request'.)
      "#{content}\n(#{explanation})"
    else
      # When used on an AiOutput
      content_first = ai_query.change_content(self.identifier, change_keyword).first
      content_last = ai_query.change_content(self.identifier, change_keyword).last
      explanation = ai_query.change_explanation(change_keyword, self.identifier, abbr)

     # Ex:
     # お寺でキラキラした10円玉を賽銭箱に投入しました。
     # (Changed the form of the adjective to past tense to match the completed action.)
     # キラキラしてる
     # ↓
     # キラキラした
     "#{corrected_sentence}\n(#{explanation})\n#{content_first}\n↓\n#{content_last}"
    end
  end
end
