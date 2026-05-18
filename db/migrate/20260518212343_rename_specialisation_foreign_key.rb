class RenameSpecialisationForeignKey < ActiveRecord::Migration[7.1]
  def change
    rename_column :specialisations_support_workers, :specialization_id, :specialisation_id
  end
end
