module Api
  class PasswordResetsController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      user = User.find_by(email: params[:email]&.downcase&.strip)
      if user
        token = SecureRandom.urlsafe_base64
        user.update!(
          reset_password_token: Digest::SHA256.hexdigest(token),
          reset_password_sent_at: Time.current
        )
        PasswordMailer.reset_email(user, token).deliver_now
      end
      # Always return 200 — don't reveal whether the email exists
      render json: { message: 'If that email is registered you will receive a reset link shortly.' }
    end

    def update
      hashed = Digest::SHA256.hexdigest(params[:token])
      user = User.find_by(reset_password_token: hashed)

      if user.nil? || user.reset_password_sent_at < 2.hours.ago
        return render json: { error: 'Reset link is invalid or has expired.' }, status: :unprocessable_entity
      end

      if user.update(password: params[:password], reset_password_token: nil, reset_password_sent_at: nil)
        render json: { message: 'Password updated successfully.' }
      else
        render json: { error: user.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end
    end
  end
end
