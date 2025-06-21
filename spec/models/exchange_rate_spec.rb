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
require 'rails_helper'

RSpec.describe ExchangeRate, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
