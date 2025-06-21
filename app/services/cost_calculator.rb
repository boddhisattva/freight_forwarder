class CostCalculator
  def valid_connection?(previous_sailing, current_sailing)
    return true unless previous_sailing

    current_sailing.departure_date >= previous_sailing.arrival_date
  end

  def convert_to_eur_cents(amount_cents, currency, departure_date)
    return amount_cents if currency == "EUR"

    exchange_rate = ExchangeRate.for_departure_date_and_currency(departure_date, currency)
    return 0 unless exchange_rate

    (amount_cents / exchange_rate.rate).round
  end

  def calculate_total_cost_eur_cents(route)
    route.sum do |sailing|
      sailing.rate_in_eur.cents
    end
  end
end
