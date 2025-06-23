module RouteStrategies
  class Fastest < Base
    def initialize(repository)
      super
      @shipping_network_builder = ShippingNetworkDurationBuilder.new
      @pathfinder = DijkstraPathfinder.new
      @time_calculator = JourneyTimeCalculator.new
    end

    def find_route(origin, destination)
      shipping_network = @shipping_network_builder.build_from_sailings(load_relevant_sailings(origin, destination))
      path = @pathfinder.find_shortest_path(shipping_network, origin, destination, @time_calculator)

      return [] if path.empty?
      format_route(path)
    end

    private

    def load_relevant_sailings(origin, destination)
      port_filter = PortConnectivityFilter.new
      port_filter.filter_relevant_sailings(origin, destination)
    end

    # def load_sailings
    #   Sailing.includes(:rate).all
    # end
  end
end
