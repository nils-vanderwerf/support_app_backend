class AddDeletedAtColumnToAppointments < ActiveRecord::Migration[7.1]
  def change
    add_column :appointments, :deleted_at, :datetime
  end
end
