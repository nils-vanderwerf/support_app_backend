class CreateConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :conversations do |t|
      t.integer :client_id
      t.integer :support_worker_id

      t.timestamps
    end
  end
end
