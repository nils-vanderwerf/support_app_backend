class AddLastAndMiddleNameToClients < ActiveRecord::Migration[7.1]
  def change
    add_column :clients, :last_name, :string
    add_column :clients, :middle_name, :string
  end
end
