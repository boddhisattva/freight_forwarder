class RouteFinderService
  def initialize(data_repository: DataRepository.new)
    @repository = data_repository
  end

  def find_route(origin_port, destination_port, criteria)
    strategy = strategy_for(criteria)
    strategy.find_route(origin_port, destination_port)
  end

  private

  def strategy_for(criteria) # TODO: Refactor this to a hash later on when more strategies are added
    case criteria
    when "cheapest-direct"
      RouteStrategies::CheapestDirectStrategy.new(@repository)
    else
      raise ArgumentError, "Unknown criteria: #{criteria}"
    end
  end
end
