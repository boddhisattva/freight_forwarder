module RouteStrategies
  class ShippingNetworkCostBuilder < ShippingNetworkBuilder
    def initialize(currency_converter)
      @currency_converter = currency_converter
    end

    private

    def create_route_option(sailing)
      eur_rate = @currency_converter.convert_to_eur(sailing.rate.amount, sailing.departure_date)

      {
        sailing: sailing,
        destination: sailing.destination_port,
        cost_cents: eur_rate.cents,
        departure_date: sailing.departure_date,
        arrival_date: sailing.arrival_date
      }
    end
  end
end
