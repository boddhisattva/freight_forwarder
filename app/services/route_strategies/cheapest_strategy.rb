# app/services/route_strategies/cheapest_strategy.rb
module RouteStrategies
  class CheapestStrategy < BaseStrategy
    def initialize(repository)
      super(repository)
      @graph_builder = RouteStrategies::CostGraphBuilder.new(@currency_converter)
      @pathfinder = RouteStrategies::BellmanFordPathfinder.new
      @cost_calculator = CostCalculator.new
    end

    def find_route(origin, destination)
      relevant_sailings = load_relevant_sailings(origin, destination)
      graph = @graph_builder.build_from_sailings(relevant_sailings)
      path = @pathfinder.find_cheapest_path(graph, origin, destination, @cost_calculator)

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
