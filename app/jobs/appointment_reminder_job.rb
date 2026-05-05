class AppointmentReminderJob < ApplicationJob
  queue_as :default

  def perform(appointment_id)
    appointment = Appointment.includes(:client, :support_worker).find_by(id: appointment_id)
    return if appointment.nil? || appointment.deleted_at.present?

    AppointmentMailer.reminder_to_client(appointment).deliver_now
    AppointmentMailer.reminder_to_support_worker(appointment).deliver_now
  end
end
