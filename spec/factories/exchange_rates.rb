# == Schema Information
#
# Table name: exchange_rates
#
#  id             :bigint           not null, primary key
#  currency       :string(3)        not null
#  departure_date :datetime         not null
#  rate           :decimal(10, 6)   not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_exchange_rates_on_departure_date               (departure_date)
#  index_exchange_rates_on_departure_date_and_currency  (departure_date,currency) UNIQUE
#
FactoryBot.define do
  factory :exchange_rate do
    departure_date { "2025-06-20 16:59:17" }
    currency { "MyString" }
    rate { "9.99" }
  end
end
