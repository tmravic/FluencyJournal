class FollowupTemplatePrompt < ApplicationRecord
  has_many :prompts, dependent: :nullify
  belongs_to :user
  scope :by_user, -> { where(user_id: Current.user.id).order(:id) }
end
