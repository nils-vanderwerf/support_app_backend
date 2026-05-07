class VettingMailer < ApplicationMailer
  def application_received(worker)
    @worker = worker
    @messages_url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/messages/admin"
    mail(to: worker.email, subject: 'Your Suppova application has been received')
  end
end
