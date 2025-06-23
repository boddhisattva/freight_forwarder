class ValidateRatesAmountCentsPositiveCheck < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint :rates, name: "rates_amount_cents_positive"
  end
end
