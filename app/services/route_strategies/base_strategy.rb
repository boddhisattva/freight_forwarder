module RouteStrategies
  class BaseStrategy
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
      sailings.compact.map do |sailing|
        {
          origin_port: sailing.origin_port,
          destination_port: sailing.destination_port,
          departure_date: sailing.departure_date.strftime("%Y-%m-%d"),
          arrival_date: sailing.arrival_date.strftime("%Y-%m-%d"),
          sailing_code: sailing.sailing_code,
          rate: sailing.rate ? format_money(sailing.rate.amount) : nil,
          rate_currency: sailing.rate ? sailing.rate.currency : nil
        }
      end
    end

    private

    def format_money(money)
      sprintf("%.2f", money.to_f)
    end
  end
end
