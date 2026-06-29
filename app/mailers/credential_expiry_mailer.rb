class CredentialExpiryMailer < ApplicationMailer
  def worker_warning(worker, credential_name, expiry_date, days_remaining)
    @worker = worker
    @credential_name = credential_name
    @expiry_date = expiry_date
    @days_remaining = days_remaining
    mail(to: worker.email, subject: "Action required: your #{credential_name} expires in #{days_remaining} days")
  end

  def admin_digest(expiring)
    @expiring = expiring
    admin_email = ENV.fetch('ADMIN_EMAIL', ENV['MAILER_FROM'])
    mail(to: admin_email, subject: "Credential expiry digest: #{expiring.count} credential(s) expiring soon")
  end
end
