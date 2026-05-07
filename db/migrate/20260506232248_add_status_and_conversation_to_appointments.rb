class AddStatusAndConversationToAppointments < ActiveRecord::Migration[7.1]
  def change
    add_column :appointments, :status, :string, default: 'approved', null: false
    add_column :appointments, :conversation_id, :integer
  end
end
