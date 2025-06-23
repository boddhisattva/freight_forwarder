require 'rails_helper'

RSpec.describe PortConnectivityFilter do
  subject(:shipping_route_filter) { described_class.new(max_hops: max_shipping_hops) }
  let(:max_shipping_hops) { 3 }

  describe '#filter_relevant_sailings' do
    context 'cargo routing scenarios' do
      context 'with direct shipping lanes' do
        before do
          create(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', sailing_code: 'DIRECT_LANE')
        end

        it 'identifies direct cargo routes between ports' do
          shipping_lanes = shipping_route_filter.filter_relevant_sailings('CNSHA', 'NLRTM')

          expect(shipping_lanes.count).to eq(1)
          expect(shipping_lanes.first.sailing_code).to eq('DIRECT_LANE')
        end

        it 'returns empty when no maritime connection exists' do
          shipping_lanes = shipping_route_filter.filter_relevant_sailings('CNSHA', 'UNKNOWN_PORT')

          expect(shipping_lanes).to be_empty
        end
      end

      context 'with multi-port cargo routing' do
        before do
          # Shanghai -> Barcelona shipping lane
          create(:sailing, origin_port: 'CNSHA', destination_port: 'ESBCN', sailing_code: 'ASIA_EUROPE')
          # Barcelona -> Rotterdam shipping lane
          create(:sailing, origin_port: 'ESBCN', destination_port: 'NLRTM', sailing_code: 'INTRA_EUROPE')
          # Direct Shanghai -> Rotterdam route
          create(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', sailing_code: 'DIRECT_ASIA_EU')
          # Complex maritime network: A -> B -> C -> D with alternative routes
          create(:sailing, origin_port: 'PORTA', destination_port: 'PORTB', sailing_code: 'AB_ROUTE')
          create(:sailing, origin_port: 'PORTB', destination_port: 'PORTC', sailing_code: 'BC_ROUTE')
          create(:sailing, origin_port: 'PORTC', destination_port: 'PORTD', sailing_code: 'CD_ROUTE')
          create(:sailing, origin_port: 'PORTA', destination_port: 'PORTC', sailing_code: 'AC_DIRECT')
        end

        it 'identifies all relevant shipping lanes for cargo transshipment' do
          shipping_lanes = shipping_route_filter.filter_relevant_sailings('CNSHA', 'NLRTM')

          sailing_codes = shipping_lanes.pluck(:sailing_code)
          expect(sailing_codes).to contain_exactly('ASIA_EUROPE', 'INTRA_EUROPE', 'DIRECT_ASIA_EU')
        end

        it 'finds multi-hop cargo routes through transshipment ports' do
          shipping_lanes = shipping_route_filter.filter_relevant_sailings('PORTA', 'PORTD')

          sailing_codes = shipping_lanes.pluck(:sailing_code)
          expect(sailing_codes).to contain_exactly('AB_ROUTE', 'BC_ROUTE', 'CD_ROUTE', 'AC_DIRECT')
        end
      end

      context 'with shipping hop limits' do
        before do
          # Create extended maritime chain: A -> B -> C -> D -> E
          create(:sailing, origin_port: 'CHAIN_A', destination_port: 'CHAIN_B', sailing_code: 'AB_CHAIN')
          create(:sailing, origin_port: 'CHAIN_B', destination_port: 'CHAIN_C', sailing_code: 'BC_CHAIN')
          create(:sailing, origin_port: 'CHAIN_C', destination_port: 'CHAIN_D', sailing_code: 'CD_CHAIN')
          create(:sailing, origin_port: 'CHAIN_D', destination_port: 'CHAIN_E', sailing_code: 'DE_CHAIN')
        end

        it 'respects maximum cargo routing hops for efficiency' do
          short_hop_filter = described_class.new(max_hops: 2)
          shipping_lanes = short_hop_filter.filter_relevant_sailings('CHAIN_A', 'CHAIN_E')

          expect(shipping_lanes).to be_empty
        end

        it 'enables longer cargo routes with increased hop allowance' do
          extended_hop_filter = described_class.new(max_hops: 4)
          shipping_lanes = extended_hop_filter.filter_relevant_sailings('CHAIN_A', 'CHAIN_E')

          sailing_codes = shipping_lanes.pluck(:sailing_code)
          expect(sailing_codes).to include('BC_CHAIN', 'CD_CHAIN')
        end
      end
    end

    context 'maritime network edge cases' do
      context 'with circular shipping routes' do
        before do
          # Circular trade route: A -> B -> C -> A
          create(:sailing, origin_port: 'CIRCLE_A', destination_port: 'CIRCLE_B', sailing_code: 'CIRCULAR_AB')
          create(:sailing, origin_port: 'CIRCLE_B', destination_port: 'CIRCLE_C', sailing_code: 'CIRCULAR_BC')
          create(:sailing, origin_port: 'CIRCLE_C', destination_port: 'CIRCLE_A', sailing_code: 'CIRCULAR_CA')
        end

        it 'handles circular trade routes without infinite cargo loops' do
          shipping_lanes = shipping_route_filter.filter_relevant_sailings('CIRCLE_A', 'CIRCLE_C')

          sailing_codes = shipping_lanes.pluck(:sailing_code)
          expect(sailing_codes).to contain_exactly('CIRCULAR_AB', 'CIRCULAR_BC', 'CIRCULAR_CA')
        end
      end

      context 'with isolated maritime networks' do
        before do
          # Isolated shipping network 1: A -> B
          create(:sailing, origin_port: 'ISOLATED_A', destination_port: 'ISOLATED_B', sailing_code: 'ISOLATED_AB')
          # Isolated shipping network 2: X -> Y
          create(:sailing, origin_port: 'REMOTE_X', destination_port: 'REMOTE_Y', sailing_code: 'REMOTE_XY')
        end

        it 'recognizes disconnected port networks' do
          shipping_lanes = shipping_route_filter.filter_relevant_sailings('ISOLATED_A', 'REMOTE_Y')

          expect(shipping_lanes).to be_empty
        end
      end

      context 'with no available shipping routes' do
        it 'handles empty maritime database gracefully' do
          shipping_lanes = shipping_route_filter.filter_relevant_sailings('CNSHA', 'NLRTM')

          expect(shipping_lanes).to be_empty
        end

        it 'handles same origin and destination port requests' do
          create(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', sailing_code: 'SAMPLE_ROUTE')

          shipping_lanes = shipping_route_filter.filter_relevant_sailings('CNSHA', 'CNSHA')

          expect(shipping_lanes).to be_empty
        end
      end
    end
  end
end
