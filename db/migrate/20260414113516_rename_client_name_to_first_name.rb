class RenameClientNameToFirstName < ActiveRecord::Migration[7.1]
  def change
    rename_column :clients, :name, :first_name
  end
end
