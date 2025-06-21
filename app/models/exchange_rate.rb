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
class ExchangeRate < ApplicationRecord
  validates :departure_date, presence: true
  validates :rate, numericality: { greater_than: 0 }, presence: true
  validates :currency, presence: true, uniqueness: { scope: :departure_date }

  scope :for_departure_date, ->(departure_date) { where(departure_date: departure_date) }
  scope :for_currency, ->(currency) { where(currency: currency.downcase) }

  def self.for_departure_date_and_currency(date, currency)
    return nil if currency == "EUR"
    for_departure_date(date).for_currency(currency).first
  end
end
