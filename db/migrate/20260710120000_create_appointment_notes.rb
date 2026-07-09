class CreateAppointmentNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :appointment_notes do |t|
      t.references :appointment, null: false, foreign_key: true, index: { unique: true }
      t.references :support_worker, null: false, foreign_key: true
      t.text :content, null: false
      t.timestamps
    end
  end
end
