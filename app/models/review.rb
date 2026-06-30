class Review < ApplicationRecord
  belongs_to :client
  belongs_to :support_worker
  belongs_to :appointment

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :appointment_id, uniqueness: { message: 'already has a review' }
  validate  :appointment_must_be_past_and_approved

  private

  def appointment_must_be_past_and_approved
    return unless appointment
    errors.add(:appointment, 'must be approved') unless appointment.status == 'approved'
    errors.add(:appointment, 'must be in the past') unless appointment.date < Time.current
    errors.add(:base, 'Client does not match appointment') unless appointment.client_id == client_id
  end
end
