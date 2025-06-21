module RouteStrategies
  class CheapestDirectStrategy < BaseStrategy
    def find_route(origin, destination)
      sailings = @repository.find_direct_sailings(origin, destination)
      return [] if sailings.empty?

      cheapest = sailings.min_by { |sailing| convert_rate_to_eur(sailing)&.cents || Float::INFINITY }
      return [] unless cheapest && convert_rate_to_eur(cheapest)

      format_route([ cheapest ])
    end
  end
end
