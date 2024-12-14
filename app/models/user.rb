class User < ApplicationRecord
  has_secure_password
  belongs_to :group
  has_many :sessions, dependent: :destroy
  has_many :entries, dependent: :destroy
  has_many :notes, dependent: :destroy

  # after_initialize :create_private_group, :if => :new_record?

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # I should probably change this later
  def name
    email_address.split("@").first.capitalize
  end
end
