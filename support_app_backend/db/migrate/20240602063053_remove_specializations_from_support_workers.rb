class RemoveSpecializationsFromSupportWorkers < ActiveRecord::Migration[7.1]
  def change
    remove_column :support_workers, :specializations, :string
  end
end
