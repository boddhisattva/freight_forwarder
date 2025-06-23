class AddCheckConstraintToExchangeRatesRate < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :exchange_rates, "rate > 0", name: "exchange_rates_rate_positive", validate: false
  end
end
