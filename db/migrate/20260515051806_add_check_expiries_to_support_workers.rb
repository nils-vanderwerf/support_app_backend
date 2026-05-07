class AddCheckExpiriesToSupportWorkers < ActiveRecord::Migration[7.1]
  def change
    add_column :support_workers, :police_check_expiry, :date
    add_column :support_workers, :wwcc_expiry, :date
  end
end
