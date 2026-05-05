class AddInitiatedByToAppointments < ActiveRecord::Migration[7.1]
  def change
    add_column :appointments, :initiated_by, :string, default: 'client'
  end
end
