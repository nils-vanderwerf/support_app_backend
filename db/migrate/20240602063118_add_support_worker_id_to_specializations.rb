class AddSupportWorkerIdToSpecializations < ActiveRecord::Migration[7.1]
  def change
    add_column :specializations, :support_worker_id, :integer
  end
end
