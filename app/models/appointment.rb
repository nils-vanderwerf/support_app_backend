class Appointment < ApplicationRecord
  belongs_to :client
  belongs_to :support_worker

  belongs_to :conversation, optional: true

  scope :active, -> { where(deleted_at: nil) }
  scope :approved, -> { active.where(status: 'approved') }
  scope :pending, -> { active.where(status: 'pending') }
  validates :date, presence: true
end
