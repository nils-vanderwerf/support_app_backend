class AppointmentNote < ApplicationRecord
  belongs_to :appointment
  belongs_to :support_worker

  validates :content, presence: true
  validates :appointment_id, uniqueness: true
end
