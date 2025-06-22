# Dijkstra Pathfinder
#
# This class finds the shortest path between two ports using Dijkstra's algorithm.
#
# Algorithm(Dijkstra's algorithm) overview:
# Phase 1: Set Up the Shipping Map(List all the ships and where they go)
# Phase 2: Explore Shipping Routes by Speed Priority(Always Check Fastest First!)
# Phase 3: Reconstruct Shipping Route(Tell the Customer the Recommended Route)

module RouteStrategies
  class DijkstraPathfinder
    INFINITY = Float::INFINITY

    def find_shortest_path(shipping_network, origin_port, destination_port, journey_calculator)
      route_search_state = initialize_route_search(origin_port)

      # Systematically explore shipping routes by speed priority
      while !route_search_state[:unvisited_ports].empty?
        # Always check the port reachable in shortest time first
        current_port_info = explore_next_fastest_port(route_search_state)

        #  Reached destination
        return reconstruct_shipping_route(route_search_state, origin_port, destination_port) if current_port_info[:port] == destination_port

        check_departing_ships(shipping_network, current_port_info, route_search_state, journey_calculator)
      end

      []  # No route found between these ports
    end

    private

    def initialize_route_search(origin_port)
      {
        fastest_times: Hash.new(INFINITY).tap { |times| times[origin_port] = 0 },

        # Which sailing got us to each port (for route reconstruction)
        best_sailing_to_port: {},

        # Previous port in our route (for backtracking the full path)
        previous_port_in_route: {},

        # Priority queue: [journey_time, port, arrival_date] - explores fastest first
        # Starts with [0, "CNSHA", nil] - Shanghai at time zero, assuming we start at Shanghai
        unvisited_ports: [ [ 0, origin_port, nil ] ],

        # Ports with finalized fastest routes
        ports_with_optimal_routes: Set.new
      }
    end

    # Get next port to explore (always the one reachable fastest)
    # First iteration: Shanghai (0 days), later: whichever port is closest
    def explore_next_fastest_port(route_search_state)
      # Remove fastest reachable port from priority queue
      current_time, current_port, arrival_at_port = route_search_state[:unvisited_ports].shift

      # Mark as "solved" - we've found the absolute fastest route here
      route_search_state[:ports_with_optimal_routes].add(current_port)

      {
        journey_time: current_time,           # Total time from Shanghai to here
        port: current_port,                  # Which port we're exploring
        arrival_date: arrival_at_port        # When we arrive at this port
      }
    end

    # Check all ships departing from current port
    def check_departing_ships(shipping_network, current_port_info, route_search_state, journey_calculator)
      # Look at every ship departing from this port
      shipping_network[current_port_info[:port]].each do |shipping_route|
        # Skip ports we've already found optimal routes to
        next if route_search_state[:ports_with_optimal_routes].include?(shipping_route[:destination])

        # See if this ship offers a faster route to its destination
        update_route_if_faster(current_port_info, shipping_route, route_search_state, journey_calculator)
      end

      # Re-sort by journey time (fastest routes explored first)
      route_search_state[:unvisited_ports].sort_by!(&:first)
    end

    def update_route_if_faster(current_port_info, shipping_route, route_search_state, journey_calculator)
      # Connection validation: Can we actually make this connection?
      # (Must arrive at port before ship departs, account for layover time)
      return unless journey_calculator.valid_connection?(
        route_search_state[:best_sailing_to_port][current_port_info[:port]],
        shipping_route[:sailing]
      )

      # Calculate total journey time via this ship
      total_time = journey_calculator.calculate_total_time(
        current_port_info[:arrival_date],     # When we arrive at current port
        shipping_route[:departure_date],      # When this ship departs
        shipping_route[:arrival_date]         # When this ship arrives at destination
      )

      new_total_time = current_port_info[:journey_time] + total_time
      destination_port = shipping_route[:destination]

      # Is this faster than any route we've found to destination?
      if new_total_time < route_search_state[:fastest_times][destination_port]
        record_new_fastest_route(destination_port, new_total_time, shipping_route, current_port_info[:port], route_search_state)
      end
    end

    def record_new_fastest_route(destination_port, new_time, shipping_route, current_port, route_search_state)
      route_search_state[:fastest_times][destination_port] = new_time                     # 17 days to Rotterdam
      route_search_state[:best_sailing_to_port][destination_port] = shipping_route[:sailing]  # via QRST sailing
      route_search_state[:previous_port_in_route][destination_port] = current_port       # from Shanghai

      # Add destination to exploration queue for future connections
      route_search_state[:unvisited_ports] << [ new_time, destination_port, shipping_route[:arrival_date] ]
    end

    # Rebuild complete shipping route from our breadcrumb trail
    # CNSHA→NLRTM example: traces back from Rotterdam, finds QRST, returns [QRST]
    def reconstruct_shipping_route(route_search_state, origin_port, destination_port)
      shipping_route = []
      current_port = destination_port

      # Walk backwards through our route breadcrumbs
      # Rotterdam → (via QRST) → Shanghai
      while current_port != origin_port && route_search_state[:best_sailing_to_port][current_port]
        sailing = route_search_state[:best_sailing_to_port][current_port]
        shipping_route.unshift(sailing)  # Add to front (since we're tracing backwards)
        current_port = route_search_state[:previous_port_in_route][current_port]
      end

      # Return route if we successfully traced back to origin, empty array if impossible
      current_port == origin_port ? shipping_route : []
    end
  end
end
