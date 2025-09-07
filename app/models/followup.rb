class Followup < ApplicationRecord
  belongs_to :prompt
  belongs_to :origin, polymorphic: true

  has_and_belongs_to_many :notes
  has_and_belongs_to_many :entries
  has_and_belongs_to_many :ai_queries
  has_and_belongs_to_many :ai_outputs

  validates :source_tag, presence: true # string

  before_destroy -> {
    ai_queries.each do |ai_query|
      ai_query.ai_outputs.each { |ai_output| ai_output.destroy! }
      ai_query.destroy!
    end
  }

  def user
    if origin.is_a?(Note)
      origin.user
    elsif origin.is_a?(AiOutput)
      origin.ai_query.user
    elsif origin.is_a?(Entry)
      origin.journal.user
    elsif origin.nil?
      Current.user
    else
      origin.ai_query.journal.user
    end
  end
end
