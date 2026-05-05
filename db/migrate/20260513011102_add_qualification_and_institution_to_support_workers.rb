class AddQualificationAndInstitutionToSupportWorkers < ActiveRecord::Migration[7.1]
  def change
    add_column :support_workers, :qualification, :string
    add_column :support_workers, :institution, :string
  end
end
