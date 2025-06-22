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
      graph = @graph_builder.build_from_sailings(load_sailings)
      path = @pathfinder.find_cheapest_path(graph, origin, destination, @cost_calculator)

      return [] if path.empty?
      format_route(path)
    end

    private

    def load_sailings
      Sailing.includes(:rate).all
    end
  end
end
