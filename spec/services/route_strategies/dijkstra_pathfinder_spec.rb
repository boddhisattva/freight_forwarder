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

    context 'with 3+ leg routes' do
      let(:leg1_sailing) { build_stubbed(:sailing, sailing_code: 'LEG1', origin_port: 'CNSHA', destination_port: 'ESBCN') }
      let(:leg2_sailing) { build_stubbed(:sailing, sailing_code: 'LEG2', origin_port: 'ESBCN', destination_port: 'NLRTM') }
      let(:leg3_sailing) { build_stubbed(:sailing, sailing_code: 'LEG3', origin_port: 'NLRTM', destination_port: 'BRSSZ') }
      let(:leg4_sailing) { build_stubbed(:sailing, sailing_code: 'LEG4', origin_port: 'BRSSZ', destination_port: 'USNYC') }

      let(:direct_slow) { build_stubbed(:sailing, sailing_code: 'SLOW_DIRECT', origin_port: 'CNSHA', destination_port: 'USNYC') }

      let(:four_leg_graph) do
        Hash.new { |h, k| h[k] = [] }.tap do |g|
          g['CNSHA'] = [
            {
              sailing: leg1_sailing,
              destination: 'ESBCN',
              departure_date: DateTime.parse('2022-01-29'),
              arrival_date: DateTime.parse('2022-02-05'),
              duration: 7
            },
            {
              sailing: direct_slow,
              destination: 'USNYC',
              departure_date: DateTime.parse('2022-01-30'),
              arrival_date: DateTime.parse('2022-04-30'), # 90 days - very slow
              duration: 90
            }
          ]
          g['ESBCN'] = [
            {
              sailing: leg2_sailing,
              destination: 'NLRTM',
              departure_date: DateTime.parse('2022-02-10'),
              arrival_date: DateTime.parse('2022-02-15'),
              duration: 5
            }
          ]
          g['NLRTM'] = [
            {
              sailing: leg3_sailing,
              destination: 'BRSSZ',
              departure_date: DateTime.parse('2022-02-20'),
              arrival_date: DateTime.parse('2022-03-01'),
              duration: 9
            }
          ]
          g['BRSSZ'] = [
            {
              sailing: leg4_sailing,
              destination: 'USNYC',
              departure_date: DateTime.parse('2022-03-05'),
              arrival_date: DateTime.parse('2022-03-12'),
              duration: 7
            }
          ]
        end
      end

      before do
        allow(journey_calculator).to receive(:valid_connection?).and_return(true)

        # 4-leg route timing: Jan 29 -> Mar 12 with proper waiting
        allow(journey_calculator).to receive(:calculate_total_time)
          .with(nil, DateTime.parse('2022-01-29'), DateTime.parse('2022-02-05'))
          .and_return(7) # LEG1: 7 days

        allow(journey_calculator).to receive(:calculate_total_time)
          .with(DateTime.parse('2022-02-05'), DateTime.parse('2022-02-10'), DateTime.parse('2022-02-15'))
          .and_return(10) # LEG2: 5 days wait + 5 days travel

        allow(journey_calculator).to receive(:calculate_total_time)
          .with(DateTime.parse('2022-02-15'), DateTime.parse('2022-02-20'), DateTime.parse('2022-03-01'))
          .and_return(14) # LEG3: 5 days wait + 9 days travel

        allow(journey_calculator).to receive(:calculate_total_time)
          .with(DateTime.parse('2022-03-01'), DateTime.parse('2022-03-05'), DateTime.parse('2022-03-12'))
          .and_return(11) # LEG4: 4 days wait + 7 days travel

        # Total 4-leg: 7 + 10 + 14 + 11 = 42 days vs direct 90 days

        # Direct route: 90 days (much slower)
        allow(journey_calculator).to receive(:calculate_total_time)
          .with(nil, DateTime.parse('2022-01-30'), DateTime.parse('2022-04-30'))
          .and_return(90)
      end

      it 'finds optimal 4-leg route when faster than direct' do
        result = pathfinder.find_shortest_path(four_leg_graph, 'CNSHA', 'USNYC', journey_calculator)

        # 4-leg route: 42 days vs direct 90 days
        expect(result).to eq([ leg1_sailing, leg2_sailing, leg3_sailing, leg4_sailing ])
      end

      it 'finds 3-leg route to intermediate destination' do
        result = pathfinder.find_shortest_path(four_leg_graph, 'CNSHA', 'BRSSZ', journey_calculator)

        # 3-leg route: CNSHA->ESBCN->NLRTM->BRSSZ
        expect(result).to eq([ leg1_sailing, leg2_sailing, leg3_sailing ])
      end

      it 'respects connection timing for multi-leg routes' do
        # Break connection between leg 2 and leg 3
        allow(journey_calculator).to receive(:valid_connection?)
          .with(leg2_sailing, leg3_sailing).and_return(false)

        result = pathfinder.find_shortest_path(four_leg_graph, 'CNSHA', 'USNYC', journey_calculator)

        # Should fallback to slow direct route when multi-leg connection breaks
        expect(result).to eq([ direct_slow ])
      end

      it 'handles complex network with multiple 3+ leg options' do
        # Add alternative 3-leg route via DEHAM
        alt_leg2 = build_stubbed(:sailing, sailing_code: 'ALT2', origin_port: 'ESBCN', destination_port: 'DEHAM')
        alt_leg3 = build_stubbed(:sailing, sailing_code: 'ALT3', origin_port: 'DEHAM', destination_port: 'USNYC')

        complex_graph = four_leg_graph.deep_dup
        complex_graph['ESBCN'] << {
          sailing: alt_leg2,
          destination: 'DEHAM',
          departure_date: DateTime.parse('2022-02-10'),
          arrival_date: DateTime.parse('2022-02-14'),
          duration: 4
        }
        complex_graph['DEHAM'] = [
          {
            sailing: alt_leg3,
            destination: 'USNYC',
            departure_date: DateTime.parse('2022-02-18'),
            arrival_date: DateTime.parse('2022-02-25'),
            duration: 7
          }
        ]

        # Alternative 3-leg route timing: Jan 29 -> Feb 25 = 27 days total
        allow(journey_calculator).to receive(:calculate_total_time)
          .with(DateTime.parse('2022-02-05'), DateTime.parse('2022-02-10'), DateTime.parse('2022-02-14'))
          .and_return(9) # ALT2: 5 days wait + 4 days travel

        allow(journey_calculator).to receive(:calculate_total_time)
          .with(DateTime.parse('2022-02-14'), DateTime.parse('2022-02-18'), DateTime.parse('2022-02-25'))
          .and_return(11) # ALT3: 4 days wait + 7 days travel

        result = pathfinder.find_shortest_path(complex_graph, 'CNSHA', 'USNYC', journey_calculator)

        # Should choose fastest: 3-leg via DEHAM: 7 + 9 + 11 = 27 days vs 4-leg 42 days
        expect(result.map(&:sailing_code)).to eq([ 'LEG1', 'ALT2', 'ALT3' ])
      end

      it 'maintains valid timing sequence for 4-leg routes' do
        result = pathfinder.find_shortest_path(four_leg_graph, 'CNSHA', 'USNYC', journey_calculator)

        # Verify connection timing is checked for each transition
        expect(journey_calculator).to have_received(:valid_connection?)
          .with(nil, leg1_sailing)
        expect(journey_calculator).to have_received(:valid_connection?)
          .with(leg1_sailing, leg2_sailing)
        expect(journey_calculator).to have_received(:valid_connection?)
          .with(leg2_sailing, leg3_sailing)
        expect(journey_calculator).to have_received(:valid_connection?)
          .with(leg3_sailing, leg4_sailing)
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

      it 'finds fastest 3+ leg route with created test data' do
        # Create additional test ports and routes for 3+ leg testing
        # CNSHA -> ESBCN -> NLRTM -> BRSSZ -> USNYC (4 legs)
        create(:sailing,
          origin_port: 'BRSSZ', destination_port: 'USNYC',
          departure_date: Date.parse('2022-03-20'), arrival_date: Date.parse('2022-03-25'),
          sailing_code: 'BRSSZ_USNYC'
        )

        # Rebuild network with new route
        shipping_network = Hash.new { |h, k| h[k] = [] }
        Sailing.all.each do |sailing|
          shipping_network[sailing.origin_port] << {
            sailing: sailing,
            destination: sailing.destination_port,
            departure_date: sailing.departure_date.to_datetime,
            arrival_date: sailing.arrival_date.to_datetime
          }
        end

        real_journey_calculator = JourneyTimeCalculator.new
        result = pathfinder.find_shortest_path(shipping_network, 'CNSHA', 'USNYC', real_journey_calculator)

        # Should find a multi-hop route (likely 3+ legs)
        expect(result).not_to be_empty
        expect(result.length).to be >= 3
        expect(result.first.origin_port).to eq('CNSHA')
        expect(result.last.destination_port).to eq('USNYC')
      end
    end
  end
end
