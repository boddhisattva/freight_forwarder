module RouteStrategies
  class BellmanFordPathfinder
    INFINITY = Float::INFINITY

    def find_cheapest_path(shipping_routes, start_port, end_port, cost_calculator)
      state = initialize_algorithm_state(shipping_routes, start_port)

      find_optimal_shipping_routes(shipping_routes, state, cost_calculator)

      return [] if state[:distances][end_port] == INFINITY
      reconstruct_path(state, start_port, end_port)
    end

    private

    def initialize_algorithm_state(shipping_routes, start_port)
      # Get every port that exists in our shipping network
      all_shipping_ports = extract_all_shipping_ports(shipping_routes)

      {
        distances: Hash.new(INFINITY).tap { |h| h[start_port] = 0 },
        previous_sailing: {},
        previous_port: {},
        all_shipping_ports: all_shipping_ports
      }
    end

    def extract_all_shipping_ports(shipping_routes)
      ports = source_ports(shipping_routes) + destination_ports_from_route(shipping_routes)
      ports.uniq
    end

    def source_ports(shipping_routes)
      shipping_routes.keys
    end

    # Each route is basically an edge in our shipping_routes
    def destination_ports_from_route(shipping_routes)
      shipping_routes.values.flat_map { |edges| edges.map { |e| e[:destination] } }
    end

    def find_optimal_shipping_routes(shipping_routes, state, cost_calculator)
      (state[:all_shipping_ports].length - 1).times do |round|
        updated = false

        updated = review_available_shipping_paths(shipping_routes, state, cost_calculator) || updated

        # Early termination if no updates
        break unless updated
      end
    end

    def review_available_shipping_paths(shipping_routes, state, cost_calculator)
      updated = false

      shipping_routes.each do |source_port, edges|
        next if state[:distances][source_port] == INFINITY


        edges.each do |edge|
          if better_shipping_connection_path?(source_port, edge, state, cost_calculator)
            updated = true
          end
        end
      end

      updated
    end

    def better_shipping_connection_path?(source_port, edge, state, cost_calculator)
      destination_port = edge[:destination]
      sailing = edge[:sailing]


      # Check connection timing
      return false unless cost_calculator.valid_connection?(
        state[:previous_sailing][source_port],
        sailing
      )


      route_cost = edge[:cost_cents]
      new_cost = state[:distances][source_port] + route_cost


      # Is this new route cheaper than what we found before?
      if new_cost < state[:distances][destination_port]
        # Yes! Update our records with this better route
        update_shortest_path(destination_port, new_cost, sailing, source_port, state)
        return true
      end

      false
    end

    def update_shortest_path(destination_port, new_cost, sailing, source_port, state)
      state[:distances][destination_port] = new_cost # Update best cost
      state[:previous_sailing][destination_port] = sailing # Remember which ship sailing we took
      state[:previous_port][destination_port] = source_port # Remember which port we came from
    end

    def reconstruct_path(state, start_port, end_port)
      path = []
      current = end_port

      while current != start_port && state[:previous_sailing][current]
        sailing = state[:previous_sailing][current]
        path.unshift(sailing)
        current = state[:previous_port][current]
      end

      current == start_port ? path : []
    end
  end
end
