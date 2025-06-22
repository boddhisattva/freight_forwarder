
class CostCalculator < JourneyCalculator
  def convert_to_eur_cents(amount_cents, currency, departure_date)
    return amount_cents if currency == "EUR"

    exchange_rate = ExchangeRate.for_departure_date_and_currency(departure_date, currency)
    return 0 unless exchange_rate

    (amount_cents / exchange_rate.rate).round
  end
end
