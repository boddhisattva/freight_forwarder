require 'rails_helper'

RSpec.describe PortConnectivityFilter do
  subject(:shipping_route_filter) { described_class.new(max_hops: max_shipping_hops) }
  let(:max_shipping_hops) { 3 }

  describe '#filter_relevant_sailings' do
    context 'cargo routing scenarios' do
      context 'with direct shipping lanes' do
        before do
          sailing = build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', sailing_code: 'DIRECT_LANE')
          allow(Sailing).to receive(:pluck).with(:origin_port, :destination_port)
            .and_return([ [ 'CNSHA', 'NLRTM' ] ])

          # Mock the chained query
          mock_relation = double('SailingRelation')
          allow(Sailing).to receive(:includes).with(:rate).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(origin_port: [ 'CNSHA', 'NLRTM' ]).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(destination_port: [ 'CNSHA', 'NLRTM' ]).and_return([ sailing ])
        end

        it 'identifies direct cargo routes between ports' do
          shipping_lanes = shipping_route_filter.filter_relevant_sailings('CNSHA', 'NLRTM')

          expect(shipping_lanes.count).to eq(1)
          expect(shipping_lanes.first.sailing_code).to eq('DIRECT_LANE')
        end

        it 'returns empty when no maritime connection exists' do
          mock_relation = double('SailingRelation')
          allow(Sailing).to receive(:includes).with(:rate).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(origin_port: []).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(destination_port: []).and_return([])

          shipping_lanes = shipping_route_filter.filter_relevant_sailings('CNSHA', 'UNKNOWN_PORT')

          expect(shipping_lanes).to be_empty
        end
      end

      context 'with multi-port cargo routing' do
        before do
          # Mock the port connectivity data
          port_pairs = [
            [ 'CNSHA', 'ESBCN' ], [ 'CNSHA', 'NLRTM' ],
            [ 'ESBCN', 'NLRTM' ],
            [ 'PORTA', 'PORTB' ], [ 'PORTA', 'PORTC' ],
            [ 'PORTB', 'PORTC' ], [ 'PORTC', 'PORTD' ]
          ]

          allow(Sailing).to receive(:pluck).with(:origin_port, :destination_port)
            .and_return(port_pairs)

          # Mock the filtered sailings
          sailings = [
            build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'ESBCN', sailing_code: 'ASIA_EUROPE'),
            build_stubbed(:sailing, origin_port: 'ESBCN', destination_port: 'NLRTM', sailing_code: 'INTRA_EUROPE'),
            build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', sailing_code: 'DIRECT_ASIA_EU')
          ]

          mock_relation = double('SailingRelation')
          allow(Sailing).to receive(:includes).with(:rate).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(origin_port: [ 'CNSHA', 'ESBCN', 'NLRTM' ]).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(destination_port: [ 'CNSHA', 'ESBCN', 'NLRTM' ]).and_return(sailings)
        end

        it 'identifies all relevant shipping lanes for cargo transshipment' do
          shipping_lanes = shipping_route_filter.filter_relevant_sailings('CNSHA', 'NLRTM')

          sailing_codes = shipping_lanes.map(&:sailing_code)
          expect(sailing_codes).to contain_exactly('ASIA_EUROPE', 'INTRA_EUROPE', 'DIRECT_ASIA_EU')
        end

        it 'finds multi-hop cargo routes through transshipment ports' do
          multi_hop_sailings = [
            build_stubbed(:sailing, origin_port: 'PORTA', destination_port: 'PORTB', sailing_code: 'AB_ROUTE'),
            build_stubbed(:sailing, origin_port: 'PORTB', destination_port: 'PORTC', sailing_code: 'BC_ROUTE'),
            build_stubbed(:sailing, origin_port: 'PORTC', destination_port: 'PORTD', sailing_code: 'CD_ROUTE'),
            build_stubbed(:sailing, origin_port: 'PORTA', destination_port: 'PORTC', sailing_code: 'AC_DIRECT')
          ]

          mock_relation = double('SailingRelation')
          allow(Sailing).to receive(:includes).with(:rate).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(origin_port: [ 'PORTA', 'PORTB', 'PORTC', 'PORTD' ]).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(destination_port: [ 'PORTA', 'PORTB', 'PORTC', 'PORTD' ]).and_return(multi_hop_sailings)

          shipping_lanes = shipping_route_filter.filter_relevant_sailings('PORTA', 'PORTD')

          sailing_codes = shipping_lanes.map(&:sailing_code)
          expect(sailing_codes).to contain_exactly('AB_ROUTE', 'BC_ROUTE', 'CD_ROUTE', 'AC_DIRECT')
        end
      end

      context 'with shipping hop limits' do
        before do
          # Mock extended maritime chain: A -> B -> C -> D -> E
          port_pairs = [
            [ 'CHAIN_A', 'CHAIN_B' ], [ 'CHAIN_B', 'CHAIN_C' ],
            [ 'CHAIN_C', 'CHAIN_D' ], [ 'CHAIN_D', 'CHAIN_E' ]
          ]

          allow(Sailing).to receive(:pluck).with(:origin_port, :destination_port)
            .and_return(port_pairs)
        end

        it 'respects maximum cargo routing hops for efficiency' do
          mock_relation = double('SailingRelation')
          allow(Sailing).to receive(:includes).with(:rate).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(origin_port: []).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(destination_port: []).and_return([])

          short_hop_filter = described_class.new(max_hops: 2)
          shipping_lanes = short_hop_filter.filter_relevant_sailings('CHAIN_A', 'CHAIN_E')

          expect(shipping_lanes).to be_empty
        end

        it 'enables longer cargo routes with increased hop allowance' do
          chain_sailings = [
            build_stubbed(:sailing, origin_port: 'CHAIN_B', destination_port: 'CHAIN_C', sailing_code: 'BC_CHAIN'),
            build_stubbed(:sailing, origin_port: 'CHAIN_C', destination_port: 'CHAIN_D', sailing_code: 'CD_CHAIN')
          ]

          mock_relation = double('SailingRelation')
          allow(Sailing).to receive(:includes).with(:rate).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(origin_port: [ 'CHAIN_B', 'CHAIN_C', 'CHAIN_D' ]).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(destination_port: [ 'CHAIN_B', 'CHAIN_C', 'CHAIN_D' ]).and_return(chain_sailings)

          extended_hop_filter = described_class.new(max_hops: 4)
          shipping_lanes = extended_hop_filter.filter_relevant_sailings('CHAIN_A', 'CHAIN_E')

          sailing_codes = shipping_lanes.map(&:sailing_code)
          expect(sailing_codes).to include('BC_CHAIN', 'CD_CHAIN')
        end
      end
    end

    context 'maritime network edge cases' do
      context 'with circular shipping routes' do
        before do
          # Mock circular trade route: A -> B -> C -> A
          port_pairs = [
            [ 'CIRCLE_A', 'CIRCLE_B' ], [ 'CIRCLE_B', 'CIRCLE_C' ], [ 'CIRCLE_C', 'CIRCLE_A' ]
          ]

          allow(Sailing).to receive(:pluck).with(:origin_port, :destination_port)
            .and_return(port_pairs)

          circular_sailings = [
            build_stubbed(:sailing, origin_port: 'CIRCLE_A', destination_port: 'CIRCLE_B', sailing_code: 'CIRCULAR_AB'),
            build_stubbed(:sailing, origin_port: 'CIRCLE_B', destination_port: 'CIRCLE_C', sailing_code: 'CIRCULAR_BC'),
            build_stubbed(:sailing, origin_port: 'CIRCLE_C', destination_port: 'CIRCLE_A', sailing_code: 'CIRCULAR_CA')
          ]

          mock_relation = double('SailingRelation')
          allow(Sailing).to receive(:includes).with(:rate).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(origin_port: [ 'CIRCLE_A', 'CIRCLE_B', 'CIRCLE_C' ]).and_return(mock_relation)
          allow(mock_relation).to receive(:where).with(destination_port: [ 'CIRCLE_A', 'CIRCLE_B', 'CIRCLE_C' ]).and_return(circular_sailings)
        end

        it 'handles circular trade routes without infinite cargo loops' do
          shipping_lanes = shipping_route_filter.filter_relevant_sailings('CIRCLE_A', 'CIRCLE_C')

          sailing_codes = shipping_lanes.map(&:sailing_code)
          expect(sailing_codes).to contain_exactly('CIRCULAR_AB', 'CIRCULAR_BC', 'CIRCULAR_CA')
        end
      end

      context 'with isolated maritime networks' do
        before do
          # Mock isolated shipping networks
          port_pairs = [
            [ 'ISOLATED_A', 'ISOLATED_B' ], [ 'REMOTE_X', 'REMOTE_Y' ]
          ]

          allow(Sailing).to receive(:pluck).with(:origin_port, :destination_port)
            .and_return(port_pairs)
          recursive_relation = double('SailingRelation', where: nil)
          allow(recursive_relation).to receive(:where).and_return(recursive_relation)
          allow(Sailing).to receive(:includes).with(:rate).and_return(recursive_relation)
          allow(recursive_relation).to receive(:where).with(destination_port: []).and_return([])
        end

        it 'recognizes disconnected port networks' do
          shipping_lanes = shipping_route_filter.filter_relevant_sailings('ISOLATED_A', 'REMOTE_Y')

          expect(shipping_lanes).to be_empty
        end
      end

      context 'with no available shipping routes' do
        before do
          allow(Sailing).to receive(:pluck).with(:origin_port, :destination_port)
            .and_return([])
          recursive_relation = double('SailingRelation', where: nil)
          allow(recursive_relation).to receive(:where).and_return(recursive_relation)
          allow(Sailing).to receive(:includes).with(:rate).and_return(recursive_relation)
          allow(recursive_relation).to receive(:where).with(destination_port: []).and_return([])
        end

        it 'handles empty maritime database gracefully' do
          shipping_lanes = shipping_route_filter.filter_relevant_sailings('CNSHA', 'NLRTM')

          expect(shipping_lanes).to be_empty
        end

        it 'handles same origin and destination port requests' do
          recursive_relation = double('SailingRelation', where: nil)
          allow(recursive_relation).to receive(:where).and_return(recursive_relation)
          allow(Sailing).to receive(:includes).with(:rate).and_return(recursive_relation)
          allow(recursive_relation).to receive(:where).with(destination_port: [ 'CNSHA' ]).and_return([])

          shipping_lanes = shipping_route_filter.filter_relevant_sailings('CNSHA', 'CNSHA')

          expect(shipping_lanes).to be_empty
        end
      end
    end

    context 'real database integration' do
      before do
        # Create minimal real data for integration test
        create(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', sailing_code: 'REAL_DIRECT')
        create(:sailing, origin_port: 'CNSHA', destination_port: 'ESBCN', sailing_code: 'REAL_ASIA_EUROPE')
        create(:sailing, origin_port: 'ESBCN', destination_port: 'NLRTM', sailing_code: 'REAL_INTRA_EUROPE')
      end

      it 'works end-to-end with real database calls' do
        shipping_lanes = shipping_route_filter.filter_relevant_sailings('CNSHA', 'NLRTM')

        sailing_codes = shipping_lanes.pluck(:sailing_code)
        expect(sailing_codes).to contain_exactly('REAL_DIRECT', 'REAL_ASIA_EUROPE', 'REAL_INTRA_EUROPE')
      end
    end
  end
end
