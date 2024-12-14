class Entry < ApplicationRecord
  belongs_to :user, optional: true
  has_many :commits, dependent: :destroy
  has_many :notes, dependent: :destroy

  validates :title, presence: true
  validates :content, presence: true

  scope :ordered, -> { order(created_at: :desc) }

  # after_create_commit -> { broadcast_prepend_later_to "entries" }
  # after_update_commit -> { broadcast_replace_later_to "entries" }
  # after_destroy_commit -> { broadcast_remove_to "entries" }
  broadcasts_to ->(entry) { "entries" }, inserts_by: :prepend
end
