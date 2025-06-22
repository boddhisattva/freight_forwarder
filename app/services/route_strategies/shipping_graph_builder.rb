module RouteStrategies
  # 🗺️ Shipping Network Builder: Creates our freight forwarding route map
  #
  # Transforms raw sailing data into a navigable shipping network where:
  # - Each port has a list of departing ships
  # - Each ship knows its destination, timing, and capacity
  #
  # Example Network from Shanghai:
  # CNSHA → [QRST→NLRTM(17d), ABCD→NLRTM(28d), ERXQ→ESBCN(14d)]
  # ESBCN → [ETRG→NLRTM(4d), ETRF→NLRTM(42d)]
  #
  # This allows pathfinding algorithms to explore: "From Shanghai, which ships can I take?"
  class ShippingGraphBuilder
    # Build navigable shipping network from available sailings
    # Returns: { port_code => [list_of_departing_ships] }
    def build_from_sailings(sailings)
      shipping_network = Hash.new { |hash, port| hash[port] = [] }

      sailings.each do |sailing|
        # Skip sailings without pricing (can't book what we can't price!)
        next unless sailing.rate

        # Add this ship to its departure port's available options
        shipping_network[sailing.origin_port] << create_shipping_route(sailing)
      end

      shipping_network
    end

    private

    def create_shipping_route(sailing)
      {
        sailing: sailing,                           # Full sailing object (for rates, etc.)
        destination: sailing.destination_port,      # Where this ship goes
        departure_date: sailing.departure_date,     # When it leaves
        arrival_date: sailing.arrival_date,         # When it arrives
        duration: sailing.duration_days             # How long at sea
      }
    end
  end
end
