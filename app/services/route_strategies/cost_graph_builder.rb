# app/services/route_strategies/cost_graph_builder.rb
module RouteStrategies
  class CostGraphBuilder
    def initialize(currency_converter)
      @currency_converter = currency_converter
    end

    def build_from_sailings(sailings)
      graph = Hash.new { |h, k| h[k] = [] }

      sailings.each do |sailing|
        next unless sailing.rate

        graph[sailing.origin_port] << create_cost_edge(sailing)
      end

      graph
    end

    private

    def create_cost_edge(sailing)
      eur_rate = @currency_converter.convert_to_eur(sailing.rate.amount, sailing.departure_date)

      {
        sailing: sailing,
        destination: sailing.destination_port,
        cost_cents: eur_rate.cents,
        departure_date: sailing.departure_date,
        arrival_date: sailing.arrival_date
      }
    end
  end
end
