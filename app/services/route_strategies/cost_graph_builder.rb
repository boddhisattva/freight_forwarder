module RouteStrategies
  class CostGraphBuilder
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
      {
        sailing: sailing,
        destination: sailing.destination_port,
        cost_cents: sailing.rate_in_eur.cents,
        departure_date: sailing.departure_date,
        arrival_date: sailing.arrival_date
      }
    end
  end
end
