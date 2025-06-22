require 'rails_helper'

RSpec.describe RouteStrategies::BellmanFordPathfinder do
  subject(:pathfinder) { described_class.new }

  let(:cost_calculator) { instance_double(CostCalculator) }

  describe '#find_cheapest_path' do
    context 'with simple direct route' do
      let(:sailing) { build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM') }
      let(:graph) do
        {
          'CNSHA' => [
            {
              sailing: sailing,
              destination: 'NLRTM',
              cost_cents: 41011,
              departure_date: DateTime.parse('2022-01-30'),
              arrival_date: DateTime.parse('2022-03-05')
            }
          ]
        }
      end

      before do
        allow(cost_calculator).to receive(:valid_connection?).and_return(true)
      end

      it 'finds direct route successfully' do
        result = pathfinder.find_cheapest_path(graph, 'CNSHA', 'NLRTM', cost_calculator)

        expect(result).to eq([ sailing ])
      end

      it 'returns empty array when destination unreachable' do
        result = pathfinder.find_cheapest_path(graph, 'CNSHA', 'UNKNOWN', cost_calculator)

        expect(result).to eq([])
      end
    end

    context 'with multi-hop route (Barcelona scenario)' do
      let(:shanghai_sailing) { build_stubbed(:sailing,
        origin_port: 'CNSHA',
        destination_port: 'ESBCN',
        sailing_code: 'ERXQ'
      ) }

      let(:barcelona_sailing) { build_stubbed(:sailing,
        origin_port: 'ESBCN',
        destination_port: 'NLRTM',
        sailing_code: 'ETRG'
      ) }

      let(:direct_sailing) { build_stubbed(:sailing,
        origin_port: 'CNSHA',
        destination_port: 'NLRTM',
        sailing_code: 'MNOP'
      ) }

      let(:graph) do
        {
          'CNSHA' => [
            {
              sailing: shanghai_sailing,
              destination: 'ESBCN',
              cost_cents: 26196, # €261.96
              departure_date: DateTime.parse('2022-01-29'),
              arrival_date: DateTime.parse('2022-02-12')
            },
            {
              sailing: direct_sailing,
              destination: 'NLRTM',
              cost_cents: 41011, # €410.11
              departure_date: DateTime.parse('2022-01-30'),
              arrival_date: DateTime.parse('2022-03-05')
            }
          ],
          'ESBCN' => [
            {
              sailing: barcelona_sailing,
              destination: 'NLRTM',
              cost_cents: 6093, # €60.93
              departure_date: DateTime.parse('2022-02-16'),
              arrival_date: DateTime.parse('2022-02-20')
            }
          ]
        }
      end

      before do
        allow(cost_calculator).to receive(:valid_connection?).and_return(true)
      end

      it 'finds cheaper multi-hop route over direct route' do
        result = pathfinder.find_cheapest_path(graph, 'CNSHA', 'NLRTM', cost_calculator)

        # Barcelona route: €261.96 + €60.93 = €322.89 < €410.11 direct
        expect(result).to eq([ shanghai_sailing, barcelona_sailing ])
      end

      it 'respects connection timing constraints' do
        # Invalid connection - arrives after next ship departs
        allow(cost_calculator).to receive(:valid_connection?)
          .with(nil, shanghai_sailing).and_return(true)
        allow(cost_calculator).to receive(:valid_connection?)
          .with(nil, direct_sailing).and_return(true)
        allow(cost_calculator).to receive(:valid_connection?)
          .with(shanghai_sailing, barcelona_sailing).and_return(false)

        result = pathfinder.find_cheapest_path(graph, 'CNSHA', 'NLRTM', cost_calculator)

        # Should fall back to direct route when connection invalid
        expect(result).to eq([ direct_sailing ])
      end
    end

    context 'with 3+ leg routes' do
      let(:leg1_sailing) { build_stubbed(:sailing, sailing_code: 'LEG1', origin_port: 'CNSHA', destination_port: 'ESBCN') }
      let(:leg2_sailing) { build_stubbed(:sailing, sailing_code: 'LEG2', origin_port: 'ESBCN', destination_port: 'NLRTM') }
      let(:leg3_sailing) { build_stubbed(:sailing, sailing_code: 'LEG3', origin_port: 'NLRTM', destination_port: 'BRSSZ') }
      let(:leg4_sailing) { build_stubbed(:sailing, sailing_code: 'LEG4', origin_port: 'BRSSZ', destination_port: 'USNYC') }

      let(:direct_expensive) { build_stubbed(:sailing, sailing_code: 'EXPENSIVE', origin_port: 'CNSHA', destination_port: 'USNYC') }

      let(:three_leg_graph) do
        {
          'CNSHA' => [
            {
              sailing: leg1_sailing,
              destination: 'ESBCN',
              cost_cents: 15000, # €150.00
              departure_date: DateTime.parse('2022-01-29'),
              arrival_date: DateTime.parse('2022-02-05')
            },
            {
              sailing: direct_expensive,
              destination: 'USNYC',
              cost_cents: 200000, # €2000.00 (expensive)
              departure_date: DateTime.parse('2022-01-30'),
              arrival_date: DateTime.parse('2022-03-15')
            }
          ],
          'ESBCN' => [
            {
              sailing: leg2_sailing,
              destination: 'NLRTM',
              cost_cents: 8000, # €80.00
              departure_date: DateTime.parse('2022-02-10'),
              arrival_date: DateTime.parse('2022-02-15')
            }
          ],
          'NLRTM' => [
            {
              sailing: leg3_sailing,
              destination: 'BRSSZ',
              cost_cents: 12000, # €120.00
              departure_date: DateTime.parse('2022-02-20'),
              arrival_date: DateTime.parse('2022-03-01')
            }
          ],
          'BRSSZ' => [
            {
              sailing: leg4_sailing,
              destination: 'USNYC',
              cost_cents: 9000, # €90.00
              departure_date: DateTime.parse('2022-03-05'),
              arrival_date: DateTime.parse('2022-03-12')
            }
          ]
        }
      end

      before do
        allow(cost_calculator).to receive(:valid_connection?).and_return(true)
      end

      it 'finds optimal 4-leg route when cheaper than direct' do
        result = pathfinder.find_cheapest_path(three_leg_graph, 'CNSHA', 'USNYC', cost_calculator)

        # 4-leg route: €150 + €80 + €120 + €90 = €440 vs direct €2000
        expect(result).to eq([ leg1_sailing, leg2_sailing, leg3_sailing, leg4_sailing ])
      end

      it 'finds 3-leg route to intermediate destination' do
        result = pathfinder.find_cheapest_path(three_leg_graph, 'CNSHA', 'BRSSZ', cost_calculator)

        # 3-leg route: €150 + €80 + €120 = €350
        expect(result).to eq([ leg1_sailing, leg2_sailing, leg3_sailing ])
      end

      it 'respects connection timing for multi-leg routes' do
        # Break connection between leg 2 and leg 3
        allow(cost_calculator).to receive(:valid_connection?)
          .with(leg2_sailing, leg3_sailing).and_return(false)

        result = pathfinder.find_cheapest_path(three_leg_graph, 'CNSHA', 'USNYC', cost_calculator)

        # Should fallback to expensive direct route when multi-leg connection breaks
        expect(result).to eq([ direct_expensive ])
      end

      it 'handles complex network with multiple 3+ leg options' do
        # Add alternative 3-leg route
        alt_leg2 = build_stubbed(:sailing, sailing_code: 'ALT2', origin_port: 'ESBCN', destination_port: 'DEHAM')
        alt_leg3 = build_stubbed(:sailing, sailing_code: 'ALT3', origin_port: 'DEHAM', destination_port: 'USNYC')

        complex_graph = three_leg_graph.deep_dup
        complex_graph['ESBCN'] << {
          sailing: alt_leg2,
          destination: 'DEHAM',
          cost_cents: 7000, # €70.00
          departure_date: DateTime.parse('2022-02-10'),
          arrival_date: DateTime.parse('2022-02-14')
        }
        complex_graph['DEHAM'] = [
          {
            sailing: alt_leg3,
            destination: 'USNYC',
            cost_cents: 25000, # €250.00
            departure_date: DateTime.parse('2022-02-18'),
            arrival_date: DateTime.parse('2022-02-25')
          }
        ]

        result = pathfinder.find_cheapest_path(complex_graph, 'CNSHA', 'USNYC', cost_calculator)

        # Should choose cheapest: 3-leg via DEHAM: €150 + €70 + €250 = €470 vs 4-leg €440
        expect(result.map(&:sailing_code)).to eq([ 'LEG1', 'LEG2', 'LEG3', 'LEG4' ])
      end
    end

    context 'with complex multi-port graph' do
      let(:route_1) { build_stubbed(:sailing, sailing_code: 'R1') }
      let(:route_2) { build_stubbed(:sailing, sailing_code: 'R2') }
      let(:route_3) { build_stubbed(:sailing, sailing_code: 'R3') }

      let(:complex_graph) do
        {
          'A' => [
            { sailing: route_1, destination: 'B', cost_cents: 100 },
            { sailing: route_2, destination: 'C', cost_cents: 300 }
          ],
          'B' => [
            { sailing: route_3, destination: 'C', cost_cents: 50 }
          ]
        }
      end

      before do
        allow(cost_calculator).to receive(:valid_connection?).and_return(true)
      end

      it 'finds optimal path through multiple hops' do
        result = pathfinder.find_cheapest_path(complex_graph, 'A', 'C', cost_calculator)

        # A->B->C (100+50=150) cheaper than A->C (300)
        expect(result).to eq([ route_1, route_3 ])
      end
    end

    context 'edge cases' do
      let(:empty_graph) { {} }

      it 'handles empty graph' do
        result = pathfinder.find_cheapest_path(empty_graph, 'A', 'B', cost_calculator)

        expect(result).to eq([])
      end

      it 'handles same start and end port' do
        graph = { 'A' => [] }
        result = pathfinder.find_cheapest_path(graph, 'A', 'A', cost_calculator)

        expect(result).to eq([])
      end
    end
  end
end
