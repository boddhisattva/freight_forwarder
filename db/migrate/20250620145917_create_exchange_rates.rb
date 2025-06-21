class CreateExchangeRates < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    create_table :exchange_rates do |t|
      t.datetime :departure_date, null: false
      t.string :currency, null: false, limit: 3
      t.decimal :rate, precision: 10, scale: 6, null: false

      t.timestamps
    end
    # add_check_constraint :exchange_rates, "rate > 0", name: "exchange_rates_rate_positive"
    add_index :exchange_rates, [ :departure_date, :currency ], unique: true, algorithm: :concurrently
    add_index :exchange_rates, :departure_date, algorithm: :concurrently
  end
end
