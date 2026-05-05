class AddFieldOfStudyToSupportWorkers < ActiveRecord::Migration[7.1]
  def change
    add_column :support_workers, :field_of_study, :string
  end
end
