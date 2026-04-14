class AddApprovedByToSupportWorkers < ActiveRecord::Migration[7.1]
  def change
    add_column :support_workers, :approved_by_id, :integer
  end
end
