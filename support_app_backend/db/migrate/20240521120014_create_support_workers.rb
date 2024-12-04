class CreateSupportWorkers < ActiveRecord::Migration[7.1]
  def change
    create_table :support_workers do |t|
      t.string :first_name
      t.string :last_name
      t.integer :age
      t.text :bio
      t.text :experience
      t.string :phone
      t.string :email
      t.string :availability
      t.string :specializations
      t.string :location

      t.timestamps
    end
  end
end
