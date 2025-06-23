module RouteStrategies
  class Base
    def initialize(repository, currency_converter: CurrencyConverter.new)
      @repository = repository
      @currency_converter = currency_converter
    end

    protected

    def convert_rate_to_eur(sailing)
      return nil unless sailing.rate
      @currency_converter.convert_to_eur(sailing.rate.amount, sailing.departure_date)
    end

    def format_route(sailings)
      sailings.compact.map(&:as_route_hash)
    end
  end
end
