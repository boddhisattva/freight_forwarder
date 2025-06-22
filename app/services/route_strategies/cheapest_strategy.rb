# app/services/route_strategies/cheapest_strategy.rb
module RouteStrategies
  class CheapestStrategy < BaseStrategy
    def initialize(repository)
      super
      @shipping_network_builder = ShippingNetworkCostBuilder.new(@currency_converter)
      @pathfinder = BellmanFordPathfinder.new
      @cost_calculator = CostCalculator.new
    end

    def find_route(origin, destination)
      relevant_sailings = load_relevant_sailings(origin, destination)
      shipping_network = @shipping_network_builder.build_from_sailings(relevant_sailings)
      path = @pathfinder.find_cheapest_path(shipping_network, origin, destination, @cost_calculator)

      return [] if path.empty?
      format_route(path)
    end

    private

    def load_relevant_sailings(origin, destination)
      port_filter = PortConnectivityFilter.new
      port_filter.filter_relevant_sailings(origin, destination)
    end
  end
end
