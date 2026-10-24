class Followup < ApplicationRecord
  include FollowupOrigin

  belongs_to :prompt
  belongs_to :origin, polymorphic: true, optional: true

  validates :source_tag, presence: true # string

  # Deleting this also deletes its prompt (and the prompt's other child).
  # See the comment on Prompt.
  after_destroy -> { Prompt.destroy_from(self) }

  def from_note?
    origin.is_a?(Note)
  end

  # The owner of the material this followup is about. A followup whose
  # origin was deleted (nullified) falls back to the signed-in user. A
  # followup of another followup is owned by whoever owns the parent's
  # material (see followup_owner).
  def user
    origin.nil? ? Current.user : origin.followup_owner
  end

  # Lets this followup be the origin of another one (FollowupOrigin).
  def followup_owner
    user
  end
end
