module Api
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    before_action :set_csrf_cookie

    def csrf_token
      render json: { csrf_token: form_authenticity_token }
    end

    private

    def set_csrf_cookie
      token = form_authenticity_token
      cookies['CSRF-TOKEN'] = token if protect_against_forgery?
      Rails.logger.debug "CSRF Token Set: #{token}"
    end

    protected

    def verified_request?
      token = request.headers['X-CSRF-Token']
      Rails.logger.debug "CSRF Token Received: #{token}"
      super || valid_authenticity_token?(session, token)
    end
  end
end