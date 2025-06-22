# app/services/port_connectivity_filter.rb
# Core Concept used: Reachability Pruning
# Instead of loading ALL sailings, find only ports that could realistically
# be part of a route, then load sailings for just those ports.
# High level Algorithm overview:
# Phase 1: Build Lightweight Port Connectivity Map
# Phase 2: Forward Reachability (BFS from Origin)
# Phase 3: Backward Reachability (BFS from Destination)
# Phase 4: Find Relevant Ports by intersection of forward_reachable and backward_reachable ports
# Phase 5: Load Filtered Sailings
class PortConnectivityFilter
  # the maximum number of stops (or 'hops') allowed between the origin and destination ports
  MAX_HOPS = Rails.application.config.max_hops

  def initialize(max_hops: MAX_HOPS)
    @max_hops = max_hops
    @port_connections = nil
  end

  # Main method: Find all sailings that could be part of a route
  def filter_relevant_sailings(origin_port, destination_port)
    relevant_ports = find_relevant_ports(origin_port, destination_port)
    load_sailings_for_ports(relevant_ports)
  end

  private


  def find_relevant_ports(origin_port, destination_port)
    ensure_port_connections_loaded

    forward_reachable = find_forward_reachable_ports(origin_port)
    backward_reachable = find_backward_reachable_ports(destination_port)

    find_relevant_ports_by_intersection(forward_reachable, backward_reachable)
  end

  # Step 1: Find ports that could realistically be part of the route
  # By building the port connectivity map (origin -> destinations)
  def ensure_port_connections_loaded
    @port_connections ||= build_port_connectivity_map
  end

  def build_port_connectivity_map
    # Load only port pairs (much faster than full sailing objects)
    port_pairs = Sailing.pluck(:origin_port, :destination_port)

    # Group by origin port: { "CNSHA" => ["NLRTM", "ESBCN"], ... }
    group_ports_by_origin(port_pairs)
  end

  def group_ports_by_origin(port_pairs)
    connections = Hash.new { |h, k| h[k] = [] }

    port_pairs.each do |origin, destination|
      connections[origin] << destination
    end

    # Remove duplicates and return
    connections.transform_values(&:uniq)
  end

  # Step 2: Forward search - what ports can we reach FROM origin?
  def find_forward_reachable_ports(origin_port)
    breadth_first_search_forward(origin_port)
  end

  def breadth_first_search_forward(start_port)
    visited_ports = Set.new
    ports_to_explore = [ start_port ]
    current_hop = 0

    while current_hop < @max_hops && ports_to_explore.any?
      current_level_ports = ports_to_explore.dup
      ports_to_explore.clear

      current_level_ports.each do |port|
        next if visited_ports.include?(port)

        visited_ports.add(port)
        add_connected_ports_to_queue(port, ports_to_explore, visited_ports)
      end

      current_hop += 1
    end

    visited_ports.to_a
  end

  def add_connected_ports_to_queue(port, queue, visited)
    connected_ports = @port_connections[port] || []

    connected_ports.each do |connected_port|
      queue << connected_port unless visited.include?(connected_port)
    end
  end

  # Step 3: Backward search - what ports can reach the destination?
  def find_backward_reachable_ports(destination_port)
    breadth_first_search_backward(destination_port)
  end

  def breadth_first_search_backward(end_port)
    visited_ports = Set.new
    ports_to_explore = [ end_port ]
    current_hop = 0

    while current_hop < @max_hops && ports_to_explore.any?
      current_level_ports = ports_to_explore.dup
      ports_to_explore.clear

      current_level_ports.each do |port|
        next if visited_ports.include?(port)

        visited_ports.add(port)
        add_source_ports_to_queue(port, ports_to_explore, visited_ports)
      end

      current_hop += 1
    end

    visited_ports.to_a
  end

  def add_source_ports_to_queue(destination, queue, visited)
    # Find all ports that can reach this destination
    source_ports = find_ports_that_connect_to(destination)

    source_ports.each do |source_port|
      queue << source_port unless visited.include?(source_port)
    end
  end

  def find_ports_that_connect_to(destination_port)
    @port_connections.select { |_origin, destinations|
      destinations.include?(destination_port)
    }.keys
  end

  # Step 4: Find Relevant Ports by intersection of forward_reachable and backward_reachable ports
  def find_relevant_ports_by_intersection(forward_reachable, backward_reachable)
    forward_reachable & backward_reachable
  end

  # Step 5: Load only the sailings we actually need
  def load_sailings_for_ports(relevant_ports)
    return Sailing.none if relevant_ports.empty?

    Sailing.includes(:rate)
           .where(origin_port: relevant_ports)
           .where(destination_port: relevant_ports)
  end
end
