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
        # Create a separate slow direct route for this test (30 days: Jan 29 to Feb 28)
        slow_direct_sailing = build_stubbed(:sailing,
          origin_port: 'CNSHA',
          destination_port: 'NLRTM',
          sailing_code: 'SLOW_DIRECT'
        )

        # Build custom graph with slow direct route
        slow_direct_graph = Hash.new { |h, k| h[k] = [] }.tap do |g|
          g['CNSHA'] = [
            {
              sailing: slow_direct_sailing,
              destination: 'NLRTM',
              departure_date: DateTime.parse('2022-01-29'),
              arrival_date: DateTime.parse('2022-02-28'),  # 30 days
              duration: 30
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

        # Mock the journey times
        allow(journey_calculator).to receive(:calculate_total_time)
          .with(nil, DateTime.parse('2022-01-29'), DateTime.parse('2022-02-28'))
          .and_return(30)  # Slow direct route: 30 days

        # Keep existing Barcelona route mocks (22 days total)
        allow(journey_calculator).to receive(:calculate_total_time)
          .with(nil, DateTime.parse('2022-01-29'), DateTime.parse('2022-02-12'))
          .and_return(14)
        allow(journey_calculator).to receive(:calculate_total_time)
          .with(DateTime.parse('2022-02-12'), DateTime.parse('2022-02-16'), DateTime.parse('2022-02-20'))
          .and_return(8) # 4 days waiting + 4 days sailing

        result = pathfinder.find_shortest_path(slow_direct_graph, 'CNSHA', 'NLRTM', journey_calculator)

        # Barcelona route (22 days) faster than slow direct route (30 days)
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
          .and_return(9) # LEG2: 4 days wait + 5 days travel

        allow(journey_calculator).to receive(:calculate_total_time)
          .with(DateTime.parse('2022-02-15'), DateTime.parse('2022-02-20'), DateTime.parse('2022-03-01'))
          .and_return(13) # LEG3: 4 days wait + 9 days travel

        allow(journey_calculator).to receive(:calculate_total_time)
          .with(DateTime.parse('2022-03-01'), DateTime.parse('2022-03-05'), DateTime.parse('2022-03-12'))
          .and_return(10) # LEG4: 3 days wait + 7 days travel

        # Total 4-leg: 7 + 9 + 13 + 10 = 39 days vs direct 90 days

        # Direct route: 90 days (much slower)
        allow(journey_calculator).to receive(:calculate_total_time)
          .with(nil, DateTime.parse('2022-01-30'), DateTime.parse('2022-04-30'))
          .and_return(90)
      end

      it 'finds optimal 4-leg route when faster than direct' do
        result = pathfinder.find_shortest_path(four_leg_graph, 'CNSHA', 'USNYC', journey_calculator)

        # 4-leg route: 39 days vs direct 90 days
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

        # Alternative 3-leg route timing: Jan 29 -> Feb 25 = 25 days total
        allow(journey_calculator).to receive(:calculate_total_time)
          .with(DateTime.parse('2022-02-05'), DateTime.parse('2022-02-10'), DateTime.parse('2022-02-14'))
          .and_return(9) # ALT2: 4 days wait + 5 days travel

        allow(journey_calculator).to receive(:calculate_total_time)
          .with(DateTime.parse('2022-02-14'), DateTime.parse('2022-02-18'), DateTime.parse('2022-02-25'))
          .and_return(11) # ALT3: 4 days wait + 7 days travel

        result = pathfinder.find_shortest_path(complex_graph, 'CNSHA', 'USNYC', journey_calculator)

        # Should choose fastest: 3-leg via DEHAM: 7 + 9 + 11 = 27 days vs 4-leg 39 days
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

    context 'integration with response.json data' do
      it 'finds QRST as fastest route using actual data format' do
        # Load only QRST and one alternative from response.json structure
        response_data = JSON.parse(File.read(Rails.root.join('db', 'response.json')))

        # Create only QRST and ABCD sailings from real data
        qrst_data = response_data['sailings'].find { |s| s['sailing_code'] == 'QRST' }
        abcd_data = response_data['sailings'].find { |s| s['sailing_code'] == 'ABCD' }

        qrst_sailing = create(:sailing,
          origin_port: qrst_data['origin_port'],
          destination_port: qrst_data['destination_port'],
          departure_date: Date.parse(qrst_data['departure_date']),
          arrival_date: Date.parse(qrst_data['arrival_date']),
          sailing_code: qrst_data['sailing_code']
        )

        abcd_sailing = create(:sailing,
          origin_port: abcd_data['origin_port'],
          destination_port: abcd_data['destination_port'],
          departure_date: Date.parse(abcd_data['departure_date']),
          arrival_date: Date.parse(abcd_data['arrival_date']),
          sailing_code: abcd_data['sailing_code']
        )

        shipping_network = Hash.new { |h, k| h[k] = [] }
        [ qrst_sailing, abcd_sailing ].each do |sailing|
          shipping_network[sailing.origin_port] << {
            sailing: sailing,
            destination: sailing.destination_port,
            departure_date: sailing.departure_date.to_datetime,
            arrival_date: sailing.arrival_date.to_datetime
          }
        end

        real_journey_calculator = JourneyTimeCalculator.new
        result = pathfinder.find_shortest_path(shipping_network, 'CNSHA', 'NLRTM', real_journey_calculator)

        # Verify QRST wins with actual response.json dates
        expect(result.first.sailing_code).to eq('QRST')
        expect(result.first.departure_date).to eq(Date.parse('2022-01-29'))
        expect(result.first.arrival_date).to eq(Date.parse('2022-02-15'))
      end
    end
  end
end
