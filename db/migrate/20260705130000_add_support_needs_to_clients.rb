class AddSupportNeedsToClients < ActiveRecord::Migration[7.1]
  def change
    add_column :clients, :support_needs, :text
  end
end
