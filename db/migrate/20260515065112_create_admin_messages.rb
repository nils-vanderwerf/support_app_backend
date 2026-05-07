class CreateAdminMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_messages do |t|
      t.integer :support_worker_id
      t.string :sender
      t.text :content
      t.datetime :read_at

      t.timestamps
    end
  end
end
