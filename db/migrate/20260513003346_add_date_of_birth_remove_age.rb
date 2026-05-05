class AddDateOfBirthRemoveAge < ActiveRecord::Migration[7.1]
  def change
    add_column :clients, :date_of_birth, :date
    add_column :support_workers, :date_of_birth, :date
    remove_column :clients, :age, :integer
    remove_column :support_workers, :age, :integer
  end
end
