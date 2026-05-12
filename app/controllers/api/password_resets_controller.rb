module Api
  class PasswordResetsController < ApplicationController
    def create
      user = User.find_by(email: params[:email].to_s.strip.downcase)
      if user
        raw_token, hashed_token = Devise.token_generator.generate(User, :reset_password_token)
        user.reset_password_token   = hashed_token
        user.reset_password_sent_at = Time.now.utc
        user.save!(validate: false)
        begin
          PasswordResetMailer.reset_instructions(user, raw_token).deliver_now
        rescue => e
          Rails.logger.error "PasswordResetMailer failed: #{e.class}: #{e.message}"
          return render json: { error: 'Failed to send email. Please contact support.' }, status: :internal_server_error
        end
      end
      render json: { message: 'If that email is registered, you will receive a reset link shortly.' }
    end

    def reset
      user = User.reset_password_by_token(
        reset_password_token: params[:token],
        password: params[:password],
        password_confirmation: params[:password]
      )
      if user.errors.empty?
        render json: { message: 'Password updated successfully.' }
      else
        render json: { error: user.errors.full_messages.first }, status: :unprocessable_entity
      end
    end
  end
end
