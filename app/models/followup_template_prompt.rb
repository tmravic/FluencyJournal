class FollowupTemplatePrompt < ApplicationRecord
  has_many :prompts, dependent: :nullify
end
