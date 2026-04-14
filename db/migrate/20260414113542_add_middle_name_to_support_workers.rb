class AddMiddleNameToSupportWorkers < ActiveRecord::Migration[7.1]
  def change
    add_column :support_workers, :middle_name, :string
  end
end
