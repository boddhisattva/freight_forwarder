class ExchangeRateRepository
  def load_rates_incrementally(exchange_rates_data)
    exchange_rates_data.each do |date, currencies|
      create_rates_for_date(date, currencies)
    end
  end

  private

  def create_rates_for_date(date, currencies)
    currencies.each do |currency, rate|
      ExchangeRate.find_or_create_by(
        departure_date: Date.parse(date),
        currency: currency
      ) do |exchange_rate|
        exchange_rate.rate = rate
      end
    end
  end
end
