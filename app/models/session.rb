class Session < ApplicationRecord
  LIFETIME = 24.hours

  belongs_to :user
  scope :active, -> { where(created_at: LIFETIME.ago..) }
end
