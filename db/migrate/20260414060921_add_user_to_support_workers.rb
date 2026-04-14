class AddUserToSupportWorkers < ActiveRecord::Migration[7.1]
  def change
    add_reference :support_workers, :user, null: true, foreign_key: true
  end
end
