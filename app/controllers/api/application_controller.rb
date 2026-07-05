module Api
  class ApplicationController < ActionController::Base
    skip_before_action :verify_authenticity_token

    # Australia spans multiple timezones (e.g. Perth vs Sydney), so appointment times must be
    # interpreted using each person's own account location rather than a fixed zone or whatever
    # timezone a browser/device happens to report.
    AU_STATE_TIMEZONES = {
      /\bwestern australia\b|\bwa\b|\bperth\b/i               => 'Australia/Perth',
      /\bsouth australia\b|\bsa\b|\badelaide\b/i              => 'Australia/Adelaide',
      /\bnorthern territory\b|\bnt\b|\bdarwin\b/i             => 'Australia/Darwin',
      /\bqueensland\b|\bqld\b|\bbrisbane\b|\bgold coast\b|\bcairns\b/i => 'Australia/Brisbane',
      /\btasmania\b|\btas\b|\bhobart\b/i                      => 'Australia/Hobart',
      /\bvictoria\b|\bvic\b|\bmelbourne\b/i                   => 'Australia/Melbourne',
    }.freeze
    DEFAULT_AU_TIMEZONE = 'Australia/Sydney' # NSW/ACT, and the fallback when location is blank or unrecognised

    def timezone_for_location(location)
      return ActiveSupport::TimeZone[DEFAULT_AU_TIMEZONE] if location.blank?

      _, zone = AU_STATE_TIMEZONES.find { |pattern, _| location.match?(pattern) }
      ActiveSupport::TimeZone[zone || DEFAULT_AU_TIMEZONE]
    end

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