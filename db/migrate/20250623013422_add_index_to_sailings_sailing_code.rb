class AddIndexToSailingsSailingCode < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :sailings, :sailing_code, algorithm: :concurrently
  end
end
