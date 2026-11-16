class User < ApplicationRecord
  has_secure_password
  normalizes :email_address, with: ->(email) { email.strip.downcase }
  validates :email_address, presence: true
end
