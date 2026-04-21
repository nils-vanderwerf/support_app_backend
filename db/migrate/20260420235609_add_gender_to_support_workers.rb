class AddGenderToSupportWorkers < ActiveRecord::Migration[7.1]
  def change
    add_column :support_workers, :gender, :string
  end
end
