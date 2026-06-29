class CreateProgressReports < ActiveRecord::Migration[7.1]
  def change
    create_table :progress_reports do |t|
      t.integer :client_id, null: false
      t.integer :user_id, null: false
      t.text :summary, null: false
      t.integer :report_count, default: 0, null: false
      t.timestamps
    end
    add_index :progress_reports, :client_id
    add_index :progress_reports, :user_id
  end
end
