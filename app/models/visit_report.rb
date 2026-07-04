class VisitReport < ApplicationRecord
  belongs_to :appointment
  belongs_to :support_worker

  validates :appointment_id, uniqueness: true
end
