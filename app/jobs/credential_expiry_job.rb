class CredentialExpiryJob < ApplicationJob
  queue_as :default

  NOTIFY_DAYS = [30, 14, 7].freeze

  def perform
    today = Date.today
    notify_entries = []

    SupportWorker.where(status: 'approved').find_each do |worker|
      [['WWCC', worker.wwcc_expiry], ['Police Check', worker.police_check_expiry]].each do |name, expiry|
        next unless expiry.present?
        days_left = (expiry - today).to_i
        next unless NOTIFY_DAYS.include?(days_left)

        CredentialExpiryMailer.worker_warning(worker, name, expiry, days_left).deliver_now
        notify_entries << { worker: worker, credential_name: name, expiry_date: expiry, days_remaining: days_left }
      end
    end

    CredentialExpiryMailer.admin_digest(notify_entries).deliver_now if notify_entries.any?
  end
end
