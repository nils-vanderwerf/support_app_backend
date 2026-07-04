class MigrateReportsToSupportWorkerId < ActiveRecord::Migration[7.1]
  def up
    add_column :visit_reports, :support_worker_id, :integer
    add_column :progress_reports, :support_worker_id, :integer

    # Subquery syntax works on both SQLite (dev/test) and PostgreSQL (prod)
    execute <<~SQL
      UPDATE visit_reports
      SET support_worker_id = (
        SELECT id FROM support_workers WHERE support_workers.user_id = visit_reports.user_id
      )
    SQL

    execute <<~SQL
      UPDATE progress_reports
      SET support_worker_id = (
        SELECT id FROM support_workers WHERE support_workers.user_id = progress_reports.user_id
      )
    SQL

    add_index :visit_reports, :support_worker_id
    add_index :progress_reports, :support_worker_id

    remove_column :visit_reports, :user_id
    remove_column :progress_reports, :user_id
  end

  def down
    add_column :visit_reports, :user_id, :integer
    add_column :progress_reports, :user_id, :integer

    execute <<~SQL
      UPDATE visit_reports
      SET user_id = (
        SELECT user_id FROM support_workers WHERE support_workers.id = visit_reports.support_worker_id
      )
    SQL

    execute <<~SQL
      UPDATE progress_reports
      SET user_id = (
        SELECT user_id FROM support_workers WHERE support_workers.id = progress_reports.support_worker_id
      )
    SQL

    remove_index :visit_reports, :support_worker_id
    remove_index :progress_reports, :support_worker_id
    remove_column :visit_reports, :support_worker_id
    remove_column :progress_reports, :support_worker_id
  end
end
