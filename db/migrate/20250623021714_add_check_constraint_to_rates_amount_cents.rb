class AddCheckConstraintToRatesAmountCents < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :rates, "amount_cents > 0", name: "rates_amount_cents_positive", validate: false
  end
end
