class AddAdminAndWorkerVetting < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :is_admin, :boolean, default: false, null: false

    add_column :support_workers, :status, :string, default: 'pending', null: false
    add_column :support_workers, :police_check_number, :string
    add_column :support_workers, :wwcc_number, :string
    add_column :support_workers, :check_notes, :text
    add_column :support_workers, :agent_recommendation, :string

    # Grandfather existing support workers as approved
    SupportWorker.update_all(status: 'approved')
  end
end
