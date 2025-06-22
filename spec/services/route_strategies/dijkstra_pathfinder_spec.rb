require 'rails_helper'

RSpec.describe RouteStrategies::DijkstraPathfinder do
  subject(:pathfinder) { described_class.new }

  let(:journey_calculator) { instance_double(JourneyTimeCalculator) }

  describe '#find_shortest_path' do
    context 'with simple direct route' do
      let(:sailing) { build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM') }
      let(:graph) do
        Hash.new { |h, k| h[k] = [] }.tap do |g|
          g['CNSHA'] = [
            {
              sailing: sailing,
              destination: 'NLRTM',
              departure_date: DateTime.parse('2022-01-29'),
              arrival_date: DateTime.parse('2022-02-15'),
              duration: 17
            }
          ]
        end
      end

      before do
        allow(journey_calculator).to receive(:valid_connection?).and_return(true)
        allow(journey_calculator).to receive(:calculate_total_time).and_return(17)
      end

      it 'finds direct route successfully' do
        result = pathfinder.find_shortest_path(graph, 'CNSHA', 'NLRTM', journey_calculator)

        expect(result).to eq([ sailing ])
      end

      it 'returns empty array when destination unreachable' do
        result = pathfinder.find_shortest_path(graph, 'CNSHA', 'UNKNOWN', journey_calculator)

        expect(result).to eq([])
      end
    end

    context 'with fastest route scenario (direct vs multi-hop)' do
      let(:direct_sailing) { build_stubbed(:sailing,
        origin_port: 'CNSHA',
        destination_port: 'NLRTM',
        sailing_code: 'QRST'
      ) }

      let(:barcelona_leg1) { build_stubbed(:sailing,
        origin_port: 'CNSHA',
        destination_port: 'ESBCN',
        sailing_code: 'ERXQ'
      ) }

      let(:barcelona_leg2) { build_stubbed(:sailing,
        origin_port: 'ESBCN',
        destination_port: 'NLRTM',
        sailing_code: 'ETRG'
      ) }

      let(:graph) do
        Hash.new { |h, k| h[k] = [] }.tap do |g|
          g['CNSHA'] = [
            {
              sailing: direct_sailing,
              destination: 'NLRTM',
              departure_date: DateTime.parse('2022-01-29'),
              arrival_date: DateTime.parse('2022-02-15'),
              duration: 17
            },
            {
              sailing: barcelona_leg1,
              destination: 'ESBCN',
              departure_date: DateTime.parse('2022-01-29'),
              arrival_date: DateTime.parse('2022-02-12'),
              duration: 14
            }
          ]
          g['ESBCN'] = [
            {
              sailing: barcelona_leg2,
              destination: 'NLRTM',
              departure_date: DateTime.parse('2022-02-16'),
              arrival_date: DateTime.parse('2022-02-20'),
              duration: 4
            }
          ]
        end
      end

      before do
        allow(journey_calculator).to receive(:valid_connection?).and_return(true)

        # Direct route: 17 days total
        allow(journey_calculator).to receive(:calculate_total_time)
          .with(nil, DateTime.parse('2022-01-29'), DateTime.parse('2022-02-15'))
          .and_return(17)

        # Barcelona route: 14 days + 4 days waiting + 4 days sailing = 22 days total
        allow(journey_calculator).to receive(:calculate_total_time)
          .with(nil, DateTime.parse('2022-01-29'), DateTime.parse('2022-02-12'))
          .and_return(14)
        allow(journey_calculator).to receive(:calculate_total_time)
          .with(DateTime.parse('2022-02-12'), DateTime.parse('2022-02-16'), DateTime.parse('2022-02-20'))
          .and_return(8) # 4 days waiting + 4 days sailing
      end

      it 'finds faster direct route over multi-hop route' do
        result = pathfinder.find_shortest_path(graph, 'CNSHA', 'NLRTM', journey_calculator)

        # Direct route (17 days) faster than Barcelona route (22 days total)
        expect(result).to eq([ direct_sailing ])
      end

      it 'chooses multi-hop when faster than direct' do
        # Make direct route slower (30 days)
        allow(journey_calculator).to receive(:calculate_total_time)
          .with(nil, DateTime.parse('2022-01-29'), DateTime.parse('2022-02-15'))
          .and_return(30)

        result = pathfinder.find_shortest_path(graph, 'CNSHA', 'NLRTM', journey_calculator)

        # Barcelona route (22 days) faster than direct route (30 days)
        expect(result).to eq([ barcelona_leg1, barcelona_leg2 ])
      end

      it 'respects connection timing constraints' do
        # Invalid connection timing
        allow(journey_calculator).to receive(:valid_connection?)
          .with(nil, direct_sailing).and_return(true)
        allow(journey_calculator).to receive(:valid_connection?)
          .with(nil, barcelona_leg1).and_return(true)
        allow(journey_calculator).to receive(:valid_connection?)
          .with(barcelona_leg1, barcelona_leg2).and_return(false)

        result = pathfinder.find_shortest_path(graph, 'CNSHA', 'NLRTM', journey_calculator)

        # Should fall back to direct route when connection invalid
        expect(result).to eq([ direct_sailing ])
      end
    end

    context 'with priority queue behavior' do
      let(:route_a) { build_stubbed(:sailing, sailing_code: 'A') }
      let(:route_b) { build_stubbed(:sailing, sailing_code: 'B') }
      let(:route_c) { build_stubbed(:sailing, sailing_code: 'C') }

      let(:graph) do
        Hash.new { |h, k| h[k] = [] }.tap do |g|
          g['START'] = [
            { sailing: route_a, destination: 'FAST', departure_date: DateTime.parse('2022-01-01'), arrival_date: DateTime.parse('2022-01-02') },
            { sailing: route_b, destination: 'SLOW', departure_date: DateTime.parse('2022-01-01'), arrival_date: DateTime.parse('2022-01-10') }
          ]
          g['FAST'] = [
            { sailing: route_c, destination: 'END', departure_date: DateTime.parse('2022-01-03'), arrival_date: DateTime.parse('2022-01-05') }
          ]
          g['SLOW'] = [
            { sailing: route_c, destination: 'END', departure_date: DateTime.parse('2022-01-11'), arrival_date: DateTime.parse('2022-01-12') }
          ]
        end
      end

      before do
        allow(journey_calculator).to receive(:valid_connection?).and_return(true)
        allow(journey_calculator).to receive(:calculate_total_time).with(nil, DateTime.parse('2022-01-01'), DateTime.parse('2022-01-02')).and_return(1)
        allow(journey_calculator).to receive(:calculate_total_time).with(nil, DateTime.parse('2022-01-01'), DateTime.parse('2022-01-10')).and_return(9)
        allow(journey_calculator).to receive(:calculate_total_time).with(DateTime.parse('2022-01-02'), DateTime.parse('2022-01-03'), DateTime.parse('2022-01-05')).and_return(3) # 1 day wait + 2 days travel
        allow(journey_calculator).to receive(:calculate_total_time).with(DateTime.parse('2022-01-10'), DateTime.parse('2022-01-11'), DateTime.parse('2022-01-12')).and_return(2) # 1 day wait + 1 day travel
      end

      it 'explores fastest routes first (priority queue behavior)' do
        result = pathfinder.find_shortest_path(graph, 'START', 'END', journey_calculator)

        # Should explore FAST path first and find optimal route
        expect(result).to eq([ route_a, route_c ])
      end
    end

    context 'edge cases' do
      let(:empty_graph) { Hash.new { |h, k| h[k] = [] } }

      it 'handles empty graph' do
        result = pathfinder.find_shortest_path(empty_graph, 'A', 'B', journey_calculator)

        expect(result).to eq([])
      end

      it 'handles same start and end port' do
        graph = Hash.new { |h, k| h[k] = [] }
        result = pathfinder.find_shortest_path(graph, 'A', 'A', journey_calculator)

        expect(result).to eq([])
      end

      it 'handles disconnected graph' do
        graph = Hash.new { |h, k| h[k] = [] }.tap do |g|
          g['A'] = [ { sailing: build_stubbed(:sailing), destination: 'B' } ]
          g['C'] = [ { sailing: build_stubbed(:sailing), destination: 'D' } ]
        end

        allow(journey_calculator).to receive(:valid_connection?).and_return(true)
        allow(journey_calculator).to receive(:calculate_total_time).and_return(1)

        result = pathfinder.find_shortest_path(graph, 'A', 'D', journey_calculator)

        expect(result).to eq([])
      end
    end

    context 'with real database data from response.json' do
      before do
        # Load real data from response.json
        response_data = JSON.parse(File.read(Rails.root.join('db', 'response.json')))

        # Create sailings from response data
        response_data['sailings'].each do |sailing_data|
          create(:sailing,
            origin_port: sailing_data['origin_port'],
            destination_port: sailing_data['destination_port'],
            departure_date: Date.parse(sailing_data['departure_date']),
            arrival_date: Date.parse(sailing_data['arrival_date']),
            sailing_code: sailing_data['sailing_code']
          )
        end

        # Create rates from response data
        response_data['rates'].each do |rate_data|
          sailing = Sailing.find_by(sailing_code: rate_data['sailing_code'])
          next unless sailing

          # Convert rate to cents (assuming the rate is in the base currency unit)
          rate_in_cents = (BigDecimal(rate_data['rate']) * 100).to_i

          create(:rate,
            sailing: sailing,
            amount_cents: rate_in_cents,
            currency: rate_data['rate_currency']
          )
        end

        # Create exchange rates from response data
        response_data['exchange_rates'].each do |date, rates|
          create(:exchange_rate,
            departure_date: Date.parse(date),
            currency: 'usd',
            rate: BigDecimal(rates['usd'].to_s)
          )
          create(:exchange_rate,
            departure_date: Date.parse(date),
            currency: 'jpy',
            rate: BigDecimal(rates['jpy'].to_s)
          )
        end
      end

      it 'finds QRST as the fastest route from CNSHA to NLRTM using real data' do
        # Build shipping network from real data
        shipping_network = Hash.new { |h, k| h[k] = [] }

        Sailing.all.each do |sailing|
          shipping_network[sailing.origin_port] << {
            sailing: sailing,
            destination: sailing.destination_port,
            departure_date: sailing.departure_date.to_datetime,
            arrival_date: sailing.arrival_date.to_datetime
          }
        end

        # Use real journey calculator
        real_journey_calculator = JourneyTimeCalculator.new

        result = pathfinder.find_shortest_path(shipping_network, 'CNSHA', 'NLRTM', real_journey_calculator)

        # Should find QRST as the fastest route (17 days: Jan 29 to Feb 15)
        expect(result).not_to be_empty
        expect(result.first.sailing_code).to eq('QRST')
        expect(result.first.origin_port).to eq('CNSHA')
        expect(result.first.destination_port).to eq('NLRTM')
        expect(result.first.departure_date).to eq(Date.parse('2022-01-29'))
        expect(result.first.arrival_date).to eq(Date.parse('2022-02-15'))
      end

      it 'verifies QRST is indeed the fastest among all CNSHA to NLRTM routes' do
        # Get all direct routes from CNSHA to NLRTM
        direct_routes = Sailing.where(origin_port: 'CNSHA', destination_port: 'NLRTM')

        # Calculate journey times for each route
        route_times = direct_routes.map do |sailing|
          diff = sailing.arrival_date - sailing.departure_date
          journey_time = if diff.is_a?(Numeric) && diff > 1000
            (diff / 1.day).round
          else
            diff.to_i
          end
          [ sailing.sailing_code, journey_time ]
        end.sort_by(&:last)

        # QRST should be the fastest (17 days)
        fastest_route = route_times.first
        expect(fastest_route.first).to eq('QRST')
        expect(fastest_route.last).to eq(17)
      end

      it 'handles multi-hop routes correctly with real data' do
        # Build shipping network from real data
        shipping_network = Hash.new { |h, k| h[k] = [] }

        Sailing.all.each do |sailing|
          shipping_network[sailing.origin_port] << {
            sailing: sailing,
            destination: sailing.destination_port,
            departure_date: sailing.departure_date.to_datetime,
            arrival_date: sailing.arrival_date.to_datetime
          }
        end

        # Use real journey calculator
        real_journey_calculator = JourneyTimeCalculator.new

        # Test CNSHA to BRSSZ (should use CNSHA -> ESBCN -> BRSSZ route)
        result = pathfinder.find_shortest_path(shipping_network, 'CNSHA', 'BRSSZ', real_journey_calculator)

        # Should find a multi-hop route via ESBCN
        expect(result).not_to be_empty
        expect(result.length).to eq(2)
        expect(result.first.origin_port).to eq('CNSHA')
        expect(result.first.destination_port).to eq('ESBCN')
        expect(result.last.origin_port).to eq('ESBCN')
        expect(result.last.destination_port).to eq('BRSSZ')
      end
    end
  end

  describe 'private methods' do
    describe '#initialize_route_search' do
      it 'initializes state with correct structure' do
        state = pathfinder.send(:initialize_route_search, 'START')

        expect(state[:fastest_times]['START']).to eq(0)
        expect(state[:fastest_times].default).to eq(Float::INFINITY)
        expect(state[:best_sailing_to_port]).to eq({})
        expect(state[:previous_port_in_route]).to eq({})
        expect(state[:unvisited_ports]).to eq([ [ 0, 'START', nil ] ])
        expect(state[:ports_with_optimal_routes]).to be_a(Set)
        expect(state[:ports_with_optimal_routes]).to be_empty
      end
    end

    describe '#explore_next_fastest_port' do
      it 'removes and returns next node from priority queue' do
        state = {
          unvisited_ports: [ [ 5, 'B', DateTime.parse('2022-01-05') ], [ 0, 'A', nil ] ],
          ports_with_optimal_routes: Set.new
        }

        node = pathfinder.send(:explore_next_fastest_port, state)

        expect(node[:journey_time]).to eq(5)
        expect(node[:port]).to eq('B')
        expect(node[:arrival_date]).to eq(DateTime.parse('2022-01-05'))
        expect(state[:ports_with_optimal_routes]).to include('B')
        expect(state[:unvisited_ports]).to eq([ [ 0, 'A', nil ] ])
      end
    end

    describe '#record_new_fastest_route' do
      it 'updates state and adds to priority queue' do
        state = {
          fastest_times: { 'A' => 0, 'B' => Float::INFINITY },
          best_sailing_to_port: {},
          previous_port_in_route: {},
          unvisited_ports: []
        }
        sailing = build_stubbed(:sailing)
        edge = { sailing: sailing, arrival_date: DateTime.parse('2022-01-05') }

        pathfinder.send(:record_new_fastest_route, 'B', 10, edge, 'A', state)

        expect(state[:fastest_times]['B']).to eq(10)
        expect(state[:best_sailing_to_port]['B']).to eq(sailing)
        expect(state[:previous_port_in_route]['B']).to eq('A')
        expect(state[:unvisited_ports]).to include([ 10, 'B', DateTime.parse('2022-01-05') ])
      end
    end

    describe '#update_route_if_faster' do
      let(:sailing) { build_stubbed(:sailing) }
      let(:current_port_info) { { journey_time: 5, port: 'A', arrival_date: DateTime.parse('2022-01-03') } }
      let(:shipping_route) do
        {
          sailing: sailing,
          destination: 'B',
          departure_date: DateTime.parse('2022-01-04'),
          arrival_date: DateTime.parse('2022-01-06')
        }
      end
      let(:route_search_state) do
        {
          fastest_times: { 'A' => 5, 'B' => Float::INFINITY },
          best_sailing_to_port: { 'A' => nil },
          previous_port_in_route: {},
          unvisited_ports: []
        }
      end

      before do
        allow(journey_calculator).to receive(:valid_connection?).and_return(true)
        allow(journey_calculator).to receive(:calculate_total_time).and_return(3)
      end

      it 'updates path when shorter route found' do
        pathfinder.send(:update_route_if_faster, current_port_info, shipping_route, route_search_state, journey_calculator)

        expect(route_search_state[:fastest_times]['B']).to eq(8) # 5 + 3
      end

      it 'does not update when connection invalid' do
        allow(journey_calculator).to receive(:valid_connection?).and_return(false)

        pathfinder.send(:update_route_if_faster, current_port_info, shipping_route, route_search_state, journey_calculator)

        expect(route_search_state[:fastest_times]['B']).to eq(Float::INFINITY)
      end

      it 'does not update when route not shorter' do
        route_search_state[:fastest_times]['B'] = 5 # Already shorter than 5 + 3

        pathfinder.send(:update_route_if_faster, current_port_info, shipping_route, route_search_state, journey_calculator)

        expect(route_search_state[:fastest_times]['B']).to eq(5) # Unchanged
      end
    end

    describe '#check_departing_ships' do
      let(:current_port_info) { { port: 'A', journey_time: 0, arrival_date: nil } }
      let(:graph) do
        Hash.new { |h, k| h[k] = [] }.tap do |g|
          g['A'] = [
            { sailing: build_stubbed(:sailing), destination: 'B' },
            { sailing: build_stubbed(:sailing), destination: 'C' }
          ]
        end
      end
      let(:route_search_state) do
        {
          unvisited_ports: [],
          ports_with_optimal_routes: Set.new
        }
      end

      before do
        allow(pathfinder).to receive(:update_route_if_faster)
      end

      it 'processes all neighbors' do
        pathfinder.send(:check_departing_ships, graph, current_port_info, route_search_state, journey_calculator)

        expect(pathfinder).to have_received(:update_route_if_faster).twice
      end

      it 'skips visited nodes' do
        route_search_state[:ports_with_optimal_routes].add('B')

        pathfinder.send(:check_departing_ships, graph, current_port_info, route_search_state, journey_calculator)

        expect(pathfinder).to have_received(:update_route_if_faster).once
      end

      it 'sorts unvisited queue by journey time' do
        route_search_state[:unvisited_ports] = [ [ 10, 'Z' ], [ 5, 'Y' ], [ 15, 'X' ] ]

        pathfinder.send(:check_departing_ships, graph, current_port_info, route_search_state, journey_calculator)

        expect(route_search_state[:unvisited_ports]).to eq([ [ 5, 'Y' ], [ 10, 'Z' ], [ 15, 'X' ] ])
      end
    end

    describe '#reconstruct_shipping_route' do
      let(:sailing_1) { build_stubbed(:sailing, sailing_code: 'S1') }
      let(:sailing_2) { build_stubbed(:sailing, sailing_code: 'S2') }

      let(:route_search_state) do
        {
          best_sailing_to_port: {
            'B' => sailing_1,
            'C' => sailing_2
          },
          previous_port_in_route: {
            'B' => 'A',
            'C' => 'B'
          }
        }
      end

      it 'reconstructs path from end to start' do
        path = pathfinder.send(:reconstruct_shipping_route, route_search_state, 'A', 'C')

        expect(path).to eq([ sailing_1, sailing_2 ])
      end

      it 'returns empty array when path incomplete' do
        route_search_state[:best_sailing_to_port].delete('B')

        path = pathfinder.send(:reconstruct_shipping_route, route_search_state, 'A', 'C')

        expect(path).to eq([])
      end

      it 'handles single hop path' do
        path = pathfinder.send(:reconstruct_shipping_route, route_search_state, 'A', 'B')

        expect(path).to eq([ sailing_1 ])
      end
    end
  end
end
