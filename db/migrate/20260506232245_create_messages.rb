class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.integer :conversation_id
      t.string :sender_type
      t.integer :sender_id
      t.text :content

      t.timestamps
    end
  end
end
