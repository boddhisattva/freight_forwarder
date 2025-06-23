class ValidateExchangeRatesRatePositiveCheck < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint :exchange_rates, name: "exchange_rates_rate_positive"
  end
end
