module RouteStrategies
  class CheapestDirectStrategy < BaseStrategy
    def find_route(origin, destination)
      sailings = @repository.find_direct_sailings(origin, destination)

      error = validate_sailings_exist(sailings, origin, destination)
      return error if error

      cheapest = find_cheapest_sailing(sailings)

      error = validate_cheapest_sailing(cheapest, origin, destination)
      return error if error

      format_route([ cheapest ])
    end

    private

    def validate_sailings_exist(sailings, origin, destination)
      return nil unless sailings.empty?

      {
        error: "No direct sailings found between #{origin} and #{destination}",
        error_code: "NO_DIRECT_SAILINGS"
      }
    end

    def find_cheapest_sailing(sailings)
      # Float::INFINITY is useful when for e.g.,  ship doesn't have a price. Then &.cents is nil
      sailings.min_by { |sailing| convert_rate_to_eur(sailing)&.cents || Float::INFINITY }
    end

    def validate_cheapest_sailing(cheapest, origin, destination)
      return nil if cheapest && convert_rate_to_eur(cheapest)

      {
        error: "No sailings with valid rates found between #{origin} and #{destination}",
        error_code: "NO_VALID_RATES"
      }
    end
  end
end
