class RenameSpecializationsTables < ActiveRecord::Migration[7.1]
  def change
    rename_table :specializations, :specialisations
    rename_table :specializations_support_workers, :specialisations_support_workers
  end
end
