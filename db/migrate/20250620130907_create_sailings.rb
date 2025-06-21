class CreateSailings < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    create_table :sailings do |t|
      t.string :sailing_code, null: false, comment: "Sailing code"
      t.string :origin_port, null: false, comment: "Origin port"
      t.string :destination_port, null: false, comment: "Destination port"
      t.datetime :departure_date, null: false, comment: "Departure date"
      t.datetime :arrival_date, null: false, comment: "Arrival date"

      t.timestamps
    end

    add_index :sailings, [ :origin_port, :destination_port ], algorithm: :concurrently
  end
end
