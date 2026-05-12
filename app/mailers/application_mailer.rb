class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAILER_FROM', 'noreply@kindredsupport.com')
  layout "mailer"
end
