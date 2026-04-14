module Api
  class ApplicationController < ActionController::Base
    skip_before_action :verify_authenticity_token

    def csrf_token
      render json: { csrf_token: 'not-used' }
    end

    def current_user
      # Token-based auth (Authorization: Bearer <token>) for cross-domain requests
      if (token = request.headers['Authorization']&.sub(/\ABearer /, ''))
        user_id = Rails.application.message_verifier(:auth).verify(token)
        return User.find_by(id: user_id)
      end
      # Fall back to session for same-domain / local dev
      User.find_by(id: session[:user_id])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end
  end
end