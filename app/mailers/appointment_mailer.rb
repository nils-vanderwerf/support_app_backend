class AppointmentMailer < ApplicationMailer
  def reminder_to_client(appointment)
    @appointment = appointment
    @support_worker = appointment.support_worker
    mail(to: appointment.client.email, subject: "Reminder: appointment tomorrow with #{@support_worker.first_name} #{@support_worker.last_name}")
  end

  def reminder_to_support_worker(appointment)
    @appointment = appointment
    @client = appointment.client
    mail(to: appointment.support_worker.email, subject: "Reminder: appointment tomorrow with #{@client.first_name} #{@client.last_name}")
  end
end
