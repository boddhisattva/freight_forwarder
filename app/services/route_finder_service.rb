class RouteFinderService
  STRATEGY_MAP = {
    "cheapest-direct" => RouteStrategies::CheapestDirectStrategy,
    "cheapest" => RouteStrategies::CheapestStrategy,
    "fastest" => RouteStrategies::FastestStrategy
  }.freeze

  def initialize(data_repository: DataRepository.new)
    @repository = data_repository
  end

  def find_route(origin_port, destination_port, criteria)
    strategy = strategy_for(criteria)
    strategy.find_route(origin_port, destination_port)
  end

  private

  def strategy_for(criteria)
    strategy_class = STRATEGY_MAP[criteria]

    if strategy_class
      strategy_class.new(@repository)
    else
      raise ArgumentError, "Unknown criteria: #{criteria}"
    end
  end
end
