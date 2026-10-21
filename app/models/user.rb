class User < ApplicationRecord
  has_secure_password
  belongs_to :group
  has_many :sessions, dependent: :destroy
  has_many :journals, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :followup_template_prompts, dependent: :destroy
  validates :original_language, presence: true
  validates :learning_language, presence: true

  # after_initialize :create_private_group, :if => :new_record?

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # How many of this user's notes are due for study now.
  def notes_due_count
    notes.next_to_study.count
  end

  def no_notes_due?
    notes.next_to_study.empty?
  end

  # I should probably change this later
  def name
    email_address.split("@").first.capitalize
  end
end
