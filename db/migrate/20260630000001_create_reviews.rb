class CreateReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :reviews do |t|
      t.references :client,         null: false, foreign_key: true
      t.references :support_worker, null: false, foreign_key: true
      t.references :appointment,    null: false, foreign_key: true, index: { unique: true }
      t.integer    :rating,         null: false
      t.text       :comment

      t.timestamps
    end
  end
end
