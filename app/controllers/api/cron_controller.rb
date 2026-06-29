module Api
  class CronController < ApplicationController
    def credential_expiry
      secret = ENV['CRON_SECRET']
      provided = request.headers['Authorization']&.sub(/\ABearer /, '')

      unless secret.present? && ActiveSupport::SecurityUtils.secure_compare(provided.to_s, secret)
        return render json: { error: 'Unauthorized' }, status: :unauthorized
      end

      CredentialExpiryJob.perform_now
      render json: { ok: true }
    end
  end
end
