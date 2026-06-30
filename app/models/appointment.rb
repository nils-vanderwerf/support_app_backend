class Appointment < ApplicationRecord
  belongs_to :client
  belongs_to :support_worker

  belongs_to :conversation, optional: true

  scope :active, -> { where(deleted_at: nil) }
  scope :approved, -> { active.where(status: 'approved') }
  scope :pending, -> { active.where(status: 'pending') }
  validates :date, presence: true
  validate :no_overlapping_appointments

  # Rescue the DB-level exclusion constraint so a race condition that slips
  # past the Ruby validator still surfaces as a model error rather than a 500.
  def save(**options)
    super
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message.include?('no_overlapping_appointments')
    errors.add(:date, 'conflicts with an existing appointment for this support worker')
    false
  end

  private

  def no_overlapping_appointments
    return unless date.present? && support_worker_id.present?

    new_end = date + (duration || 60).minutes
    overlap = Appointment.active.where.not(id: id).where(support_worker_id: support_worker_id)
                         .any? { |a| date < a.date + (a.duration || 60).minutes && new_end > a.date }
    errors.add(:date, 'conflicts with an existing appointment for this support worker') if overlap
  end
end
