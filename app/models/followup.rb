class Followup < ApplicationRecord
  include FollowupOrigin

  belongs_to :prompt
  belongs_to :origin, polymorphic: true, optional: true

  validates :source_tag, presence: true # string

  after_destroy -> { Prompt.destroy_from(self) }

  # The owner of the material this followup is about. A followup whose
  # origin was deleted (nullified) falls back to the signed-in user. A
  # followup of another followup has no owner and raises NoMethodError, as
  # it always has.
  def user
    origin.nil? ? Current.user : origin.followup_owner
  end
end
