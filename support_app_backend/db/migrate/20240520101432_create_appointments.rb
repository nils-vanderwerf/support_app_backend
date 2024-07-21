class CreateAppointments < ActiveRecord::Migration[7.1]
  def change
    create_table :appointments do |t|
      t.datetime :date
      t.integer :duration
      t.string :location
      t.integer :user_id
      t.integer :client_id
      t.text :notes

      t.timestamps
    end
  end
end
