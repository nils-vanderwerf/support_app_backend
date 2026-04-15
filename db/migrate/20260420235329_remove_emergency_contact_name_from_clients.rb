class RemoveEmergencyContactNameFromClients < ActiveRecord::Migration[7.1]
  def change
    remove_column :clients, :emergency_contact_name, :string
  end
end
