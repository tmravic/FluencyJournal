class Followup < ApplicationRecord
  belongs_to :prompt

  has_and_belongs_to_many :notes
  has_and_belongs_to_many :entries
  has_and_belongs_to_many :ai_queries
  has_and_belongs_to_many :ai_outputs

  validates :followup_origin_class, presence: true # string
  validates :followup_origin_id, presence: true # int
  validates :source_tag, presence: true # string

  before_destroy -> {
    ai_queries.each do |ai_query|
      ai_query.ai_outputs.each { |ai_output| ai_output.destroy! }
      ai_query.destroy!
    end
  }

  def origin
    followup_origin_class.constantize.find(followup_origin_id)
  end

  def connector
    join_table_name = (followup_origin_class.pluralize + 'Followups').underscore.to_sym
    # ex: :entries_followup
    self.send(join_table_name)
  end

  def user
    if origin.is_a?(Note)
      origin.user
    else
      origin.ai_query.journal.user
    end
  end
end
