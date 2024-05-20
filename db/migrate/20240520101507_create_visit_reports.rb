class CreateVisitReports < ActiveRecord::Migration[7.1]
  def change
    create_table :visit_reports do |t|
      t.integer :user_id
      t.integer :client_id
      t.integer :appointment_id
      t.datetime :date
      t.text :activities
      t.text :observations
      t.text :follow_up_actions

      t.timestamps
    end
  end
end
