class CreateFailedEmailLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :failed_email_logs do |t|
      t.string :job_class
      t.text :arguments
      t.text :error_message
      t.datetime :failed_at
      t.datetime :resolved_at

      t.timestamps
    end
  end
end
