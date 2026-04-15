class AddEmergencyContactToSupportWorkers < ActiveRecord::Migration[7.1]
  def change
    add_column :support_workers, :emergency_contact_first_name, :string
    add_column :support_workers, :emergency_contact_last_name, :string
    add_column :support_workers, :emergency_contact_phone, :string
  end
end
