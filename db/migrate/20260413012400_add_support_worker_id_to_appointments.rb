class AddSupportWorkerIdToAppointments < ActiveRecord::Migration[7.1]
  def change
    add_column :appointments, :support_worker_id, :integer
  end
end
