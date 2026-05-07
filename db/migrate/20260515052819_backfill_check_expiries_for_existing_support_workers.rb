class BackfillCheckExpiriesForExistingSupportWorkers < ActiveRecord::Migration[7.1]
  def up
    workers = SupportWorker.where.not(police_check_number: nil)
                           .where(police_check_expiry: nil)
                           .or(SupportWorker.where.not(wwcc_number: nil).where(wwcc_expiry: nil))

    # Spread expiries realistically. First two slots are amber (expiring within 30 days)
    # so the warning state shows up in the demo without everything looking the same.
    police_check_days = [15, 25, 60, 90, 120, 180, 240, 300, 400, 500, 600, 700, 800, 900, 1000, 1095]
    wwcc_days         = [20, 45, 90, 180, 365, 500, 600, 730, 900, 1095, 1200, 1400, 1600, 1825]

    workers.each_with_index do |worker, i|
      updates = {}

      if worker.police_check_expiry.nil? && worker.police_check_number.present?
        days = police_check_days[i % police_check_days.length] + rand(-7..7)
        updates[:police_check_expiry] = Date.today + days.days
      end

      if worker.wwcc_expiry.nil? && worker.wwcc_number.present?
        days = wwcc_days[i % wwcc_days.length] + rand(-7..7)
        updates[:wwcc_expiry] = Date.today + days.days
      end

      worker.update_columns(updates) if updates.any?
    end
  end

  def down
    # Non-reversible — cannot distinguish backfilled dates from real ones
  end
end
