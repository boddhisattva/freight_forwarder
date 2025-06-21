class CurrencyConverter
  def convert_to_eur(money, departure_date)
    return money if money.currency == "EUR"

    exchange_rate = ExchangeRate.for_departure_date_and_currency(departure_date, money.currency.to_s)
    raise("No exchange rate found for #{money.currency} on #{departure_date}") unless exchange_rate

    Money.new((money.cents / exchange_rate.rate).round, "EUR")
  end
end
