module RouteStrategies
  class FastestStrategy < BaseStrategy
    def initialize(repository)
      super(repository)
      @graph_builder = ShippingGraphBuilder.new
      @pathfinder = DijkstraPathfinder.new
      @journey_calculator = JourneyTimeCalculator.new
    end

    def find_route(origin, destination)
      graph = @graph_builder.build_from_sailings(load_relevant_sailings(origin, destination))
      path = @pathfinder.find_shortest_path(graph, origin, destination, @journey_calculator)

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
