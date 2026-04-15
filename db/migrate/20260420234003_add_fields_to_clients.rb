class AddFieldsToClients < ActiveRecord::Migration[7.1]
  def change
    add_column :clients, :bio, :text
    add_column :clients, :location, :string
    add_column :clients, :email, :string
    add_column :clients, :emergency_contact_first_name, :string
    add_column :clients, :emergency_contact_last_name, :string
  end
end
