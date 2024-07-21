class CreateClients < ActiveRecord::Migration[7.1]
  def change
    create_table :clients do |t|
      t.string :name
      t.integer :age
      t.string :gender
      t.string :address
      t.string :phone
      t.text :health_conditions
      t.text :medication
      t.text :allergies
      t.string :emergency_contact_name
      t.string :emergency_contact_phone

      t.timestamps
    end
  end
end
