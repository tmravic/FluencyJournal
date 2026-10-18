class Followup < ApplicationRecord
  belongs_to :prompt
  belongs_to :origin, polymorphic: true, optional: true

  validates :source_tag, presence: true # string

  after_destroy -> { Prompt.destroy_from(self) }

  def user
    if origin.is_a?(Note)
      origin.user
    elsif origin.is_a?(AiOutput)
      origin.ai_query.user
    elsif origin.is_a?(Entry) || origin.is_a?(JournalFollowup)
      origin.journal.user
    elsif origin.nil?
      Current.user
    else
      origin.ai_query.journal.user
    end
  end
end
