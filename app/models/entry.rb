class Entry < ApplicationRecord
  belongs_to :user
  belongs_to :group
  has_many :commits, dependent: :destroy
  has_many :notes, dependent: :destroy

  validates :title, presence: true

  scope :ordered, -> { order(created_at: :desc) }
  # scope :personal, -> {  }
  # scope :private, -> {  }
  # scope :public, -> {  }
  # scope :shared (either private or publish, not personal), -> {  }

  # after_create_commit -> { broadcast_prepend_later_to "entries" }
  # after_update_commit -> { broadcast_replace_later_to "entries" }
  # after_destroy_commit -> { broadcast_remove_to "entries" }
  broadcasts_to ->(entry) { [entry.group, "entries"] }, inserts_by: :prepend
  # The signed stream name is generated from the array returned by the lambda
  # that is the first argument of the broadcasts_to method: [entry.group, "entries"].
end
