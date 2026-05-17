class FollowupTemplatePrompt < ApplicationRecord
  has_many :prompts, dependent: :nullify
  belongs_to :user
  scope :by_user, ->(user) { where(user_id: user.id).order(:id) }
end
