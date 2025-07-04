# Bellman-Ford Pathfinder
#
# This class finds the cheapest path between two ports using Bellman-Ford's algorithm.
#
# Algorithm(Bellman-Ford's algorithm) overview:
# Phase 1: Network Setup(Set up the shipping network)
# Phase 2: Explore Shipping Routes by Cost Priority
# Phase 3: Reconstruct Shipping Route to find the cheapest path

module RouteStrategies
  class BellmanFordPathfinder
    INFINITY = Float::INFINITY

    def find_cheapest_path(shipping_routes, start_port, end_port, cost_calculator)
      state = initialize_algorithm_state(shipping_routes, start_port)

      find_optimal_shipping_routes(shipping_routes, state, cost_calculator)

      return [] if state[:distances][end_port] == INFINITY
      reconstruct_shipping_itinerary(state, start_port, end_port)
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

    # Each route is basically a shipping lane in our shipping_routes
    def destination_ports_from_route(shipping_routes)
      shipping_routes.values.flat_map { |available_routes| available_routes.map { |route| route[:destination] } }
    end

    def find_optimal_shipping_routes(shipping_routes, state, cost_calculator)
      # Imagine you have 4 friends in a line and you want to pass a message to the last friend.
      # You need 3 passess max (4 people - 1) to pass the message to the last friend.
      # Same with ports, with 4 ports, we need max 3 rounds to find the best route
      (state[:all_shipping_ports].length - 1).times do |round|
        updated = false

        updated = review_available_shipping_paths(shipping_routes, state, cost_calculator) || updated

        # Early termination if no updates
        break unless updated
      end
    end

    def review_available_shipping_paths(shipping_routes, state, cost_calculator)
      updated = false

      shipping_routes.each do |source_port, available_routes|
        next if state[:distances][source_port] == INFINITY

        available_routes.each do |route|
          if better_shipping_connection_path?(source_port, route, state, cost_calculator)
            updated = true
          end
        end
      end

      updated
    end

    def better_shipping_connection_path?(source_port, route, state, cost_calculator)
      destination_port = route[:destination]
      sailing = route[:sailing]

      # Check connection timing
      return false unless cost_calculator.valid_connection?(
        state[:previous_sailing][source_port],
        sailing
      )

      route_cost = route[:cost_cents]
      new_cost = state[:distances][source_port] + route_cost

      # Is this new route cheaper than what we found before?
      if new_cost < state[:distances][destination_port]
        # Yes! Update our records with this better shipping route
        update_shortest_shipping_path(destination_port, new_cost, sailing, source_port, state)
        return true
      end

      false
    end

    def update_shortest_shipping_path(destination_port, new_cost, sailing, source_port, state)
      state[:distances][destination_port] = new_cost # Update best cost
      state[:previous_sailing][destination_port] = sailing # Remember which ship sailing we took
      state[:previous_port][destination_port] = source_port # Remember which port we came from
    end

    def reconstruct_shipping_itinerary(state, start_port, end_port)
      shipping_itinerary = []
      current = end_port

      while current != start_port && state[:previous_sailing][current]
        sailing = state[:previous_sailing][current]
        shipping_itinerary.unshift(sailing) # Add to front (since we're going backwards)
        current = state[:previous_port][current]
      end

      current == start_port ? shipping_itinerary : []
    end
  end
end
