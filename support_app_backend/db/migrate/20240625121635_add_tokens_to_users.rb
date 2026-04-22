class AddTokensToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :tokens, :json
  end
end
