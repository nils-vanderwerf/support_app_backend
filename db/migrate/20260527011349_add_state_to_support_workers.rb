class AddStateToSupportWorkers < ActiveRecord::Migration[7.1]
  def change
    add_column :support_workers, :state, :string
  end
end
