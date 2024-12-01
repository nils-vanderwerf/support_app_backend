class Appointment < ApplicationRecord
  belongs_to :client
  belongs_to :support_worker

  scope :active, -> { where(deleted_at: nil) }
end
