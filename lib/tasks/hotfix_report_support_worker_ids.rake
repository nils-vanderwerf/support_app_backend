namespace :hotfix do
  desc <<~DESC
    Verify and repair support_worker_id on visit_reports and progress_reports
    after the FK migration. Any row that the migration could not backfill
    (because its old user_id had no matching support_worker) will have
    support_worker_id: NULL. This task reports them and attempts repair
    via the appointment association before giving up.

    Run after deploying the MigrateReportsToSupportWorkerId migration:
      rails hotfix:report_support_worker_ids
  DESC
  task report_support_worker_ids: :environment do
    puts "=== Hotfix: support_worker_id backfill check ==="

    fix_visit_reports
    fix_progress_reports

    puts "\nDone."
  end

  def fix_visit_reports
    orphaned = VisitReport.where(support_worker_id: nil)
    puts "\nVisitReports with null support_worker_id: #{orphaned.count}"
    return if orphaned.none?

    repaired = 0
    unresolvable = []

    orphaned.includes(appointment: :support_worker).each do |report|
      worker = report.appointment&.support_worker
      if worker
        report.update_columns(support_worker_id: worker.id)
        repaired += 1
        puts "  Repaired visit_report ##{report.id} → support_worker ##{worker.id}"
      else
        unresolvable << report.id
        puts "  UNRESOLVABLE visit_report ##{report.id} — no appointment or worker"
      end
    end

    puts "  Repaired: #{repaired}, Unresolvable: #{unresolvable.length}"

    if unresolvable.any?
      puts "\n  WARNING: The following visit_report IDs could not be linked to a support worker"
      puts "  and should be reviewed or deleted manually:"
      puts "  #{unresolvable.join(', ')}"
      puts "\n  To delete them run:  rails hotfix:cleanup_orphaned_reports"
    end
  end

  def fix_progress_reports
    orphaned = ProgressReport.where(support_worker_id: nil)
    puts "\nProgressReports with null support_worker_id: #{orphaned.count}"
    return if orphaned.none?

    puts "  WARNING: #{orphaned.count} progress report(s) have no support_worker_id."
    puts "  These cannot be auto-repaired (no appointment to derive from)."
    puts "  Review and delete manually, or run:  rails hotfix:cleanup_orphaned_reports"
    orphaned.each { |r| puts "    progress_report ##{r.id} — client_id: #{r.client_id}" }
  end

  desc "Delete visit_reports and progress_reports with no support_worker_id (orphaned by FK migration). Run AFTER reviewing hotfix:report_support_worker_ids output."
  task cleanup_orphaned_reports: :environment do
    vr_count = VisitReport.where(support_worker_id: nil).count
    pr_count = ProgressReport.where(support_worker_id: nil).count

    puts "Deleting #{vr_count} orphaned visit_report(s) and #{pr_count} orphaned progress_report(s)..."

    VisitReport.where(support_worker_id: nil).delete_all
    ProgressReport.where(support_worker_id: nil).delete_all

    puts "Done."
  end
end
