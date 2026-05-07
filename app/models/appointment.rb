class Appointment < ApplicationRecord
  belongs_to :client
  belongs_to :support_worker

  belongs_to :conversation, optional: true

  scope :active, -> { where(deleted_at: nil) }
  scope :approved, -> { active.where(status: 'approved') }
  scope :pending, -> { active.where(status: 'pending') }
  validates :date, presence: true
  validate :no_overlapping_appointments

  private

  def no_overlapping_appointments
    return unless date.present?

    new_end = date + (duration || 60).minutes

    if support_worker_id.present?
      overlap = Appointment.active.where.not(id: id).where(support_worker_id: support_worker_id)
                           .any? { |a| date < a.date + (a.duration || 60).minutes && new_end > a.date }
      errors.add(:date, 'conflicts with an existing appointment for this support worker') if overlap
    end

  end
end
