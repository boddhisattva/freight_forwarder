module RouteStrategies
  class ShippingNetworkDurationBuilder < ShippingNetworkBuilder
    private

    def create_route_option(sailing)
      {
        sailing: sailing,
        destination: sailing.destination_port,
        departure_date: sailing.departure_date,
        arrival_date: sailing.arrival_date,
        duration: sailing.duration_days
      }
    end
  end
end
