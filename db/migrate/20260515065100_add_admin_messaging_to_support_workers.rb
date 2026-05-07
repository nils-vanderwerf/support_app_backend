class AddAdminMessagingToSupportWorkers < ActiveRecord::Migration[7.1]
  def change
    add_column :support_workers, :admin_note, :text
    add_column :support_workers, :rejected_at, :datetime
  end
end
