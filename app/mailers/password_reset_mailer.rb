class PasswordResetMailer < ApplicationMailer
  def reset_instructions(user, token)
    @user = user
    @reset_url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/reset-password/#{token}"
    mail(to: user.email, subject: 'Reset your Suppova password')
  end
end
