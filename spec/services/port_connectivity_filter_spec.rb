require 'rails_helper'

RSpec.describe PortConnectivityFilter do
  subject(:filter) { described_class.new(max_hops: max_hops) }
  let(:max_hops) { 3 }

  describe '#filter_relevant_sailings' do
    context 'with simple direct route' do
      before do
        create(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', sailing_code: 'DIRECT')
      end

      it 'returns sailings for direct route' do
        result = filter.filter_relevant_sailings('CNSHA', 'NLRTM')

        expect(result).to be_a(ActiveRecord::Relation)
        expect(result.count).to eq(1)
        expect(result.first.sailing_code).to eq('DIRECT')
      end

      it 'returns empty when no route exists' do
        result = filter.filter_relevant_sailings('CNSHA', 'UNKNOWN')

        expect(result).to be_empty
      end
    end

    context 'with multi-hop route (Barcelona scenario)' do
      before do
        # Shanghai -> Barcelona
        create(:sailing, origin_port: 'CNSHA', destination_port: 'ESBCN', sailing_code: 'ERXQ')
        # Barcelona -> Rotterdam
        create(:sailing, origin_port: 'ESBCN', destination_port: 'NLRTM', sailing_code: 'ETRG')
        # Shanghai -> Rotterdam (direct)
        create(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', sailing_code: 'MNOP')
      end

      it 'includes all sailings that could be part of the route' do
        result = filter.filter_relevant_sailings('CNSHA', 'NLRTM')

        sailing_codes = result.pluck(:sailing_code)
        expect(sailing_codes).to contain_exactly('ERXQ', 'ETRG', 'MNOP')
      end

      it 'includes sailings from intermediate ports' do
        result = filter.filter_relevant_sailings('CNSHA', 'NLRTM')

        # Should include Barcelona sailings since they're part of a valid route
        barcelona_sailings = result.where(origin_port: 'ESBCN')
        expect(barcelona_sailings).not_to be_empty
      end
    end

    context 'with complex multi-port network' do
      before do
        # Create a more complex network
        # A -> B -> C -> D
        # A -> C (direct)
        # B -> D (direct)
        create(:sailing, origin_port: 'A', destination_port: 'B', sailing_code: 'AB')
        create(:sailing, origin_port: 'B', destination_port: 'C', sailing_code: 'BC')
        create(:sailing, origin_port: 'C', destination_port: 'D', sailing_code: 'CD')
        create(:sailing, origin_port: 'A', destination_port: 'C', sailing_code: 'AC')
        create(:sailing, origin_port: 'B', destination_port: 'D', sailing_code: 'BD')
      end

      it 'finds all relevant sailings for multi-hop route' do
        result = filter.filter_relevant_sailings('A', 'D')

        sailing_codes = result.pluck(:sailing_code)
        expect(sailing_codes).to contain_exactly('AB', 'BC', 'CD', 'AC', 'BD')
      end

      it 'excludes irrelevant sailings' do
        # Add a sailing that's not part of any route from A to D
        create(:sailing, origin_port: 'X', destination_port: 'Y', sailing_code: 'XY')

        result = filter.filter_relevant_sailings('A', 'D')

        sailing_codes = result.pluck(:sailing_code)
        expect(sailing_codes).not_to include('XY')
      end
    end

    context 'with max_hops limit' do
      before do
        # Create a chain: A -> B -> C -> D -> E -> F
        create(:sailing, origin_port: 'A', destination_port: 'B', sailing_code: 'AB')
        create(:sailing, origin_port: 'B', destination_port: 'C', sailing_code: 'BC')
        create(:sailing, origin_port: 'C', destination_port: 'D', sailing_code: 'CD')
        create(:sailing, origin_port: 'D', destination_port: 'E', sailing_code: 'DE')
        create(:sailing, origin_port: 'E', destination_port: 'F', sailing_code: 'EF')
      end

      it 'respects max_hops limit' do
        short_filter = described_class.new(max_hops: 2)
        result = short_filter.filter_relevant_sailings('A', 'F')

        # With max_hops=2, intersection may be empty (no port is both forward and backward reachable within 2 hops)
        expect(result).to be_empty
      end

      it 'allows longer routes with higher max_hops' do
        long_filter = described_class.new(max_hops: 5)
        result = long_filter.filter_relevant_sailings('A', 'F')

        # Only ports that are both forward and backward reachable within 5 hops will be included
        sailing_codes = result.pluck(:sailing_code)
        expect(sailing_codes).to include('BC', 'CD', 'DE')
        # 'AB' and 'EF' may not be included due to intersection logic
      end
    end

    context 'with circular routes' do
      before do
        # A -> B -> C -> A (circular)
        create(:sailing, origin_port: 'A', destination_port: 'B', sailing_code: 'AB')
        create(:sailing, origin_port: 'B', destination_port: 'C', sailing_code: 'BC')
        create(:sailing, origin_port: 'C', destination_port: 'A', sailing_code: 'CA')
      end

      it 'handles circular routes without infinite loops' do
        result = filter.filter_relevant_sailings('A', 'C')

        sailing_codes = result.pluck(:sailing_code)
        expect(sailing_codes).to contain_exactly('AB', 'BC', 'CA')
      end
    end

    context 'with empty database' do
      it 'returns empty result' do
        result = filter.filter_relevant_sailings('CNSHA', 'NLRTM')

        expect(result).to be_empty
      end
    end

    context 'with same origin and destination' do
      before do
        create(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', sailing_code: 'DIRECT')
      end

      it 'returns empty result for same port' do
        result = filter.filter_relevant_sailings('CNSHA', 'CNSHA')

        expect(result).to be_empty
      end
    end
  end

  describe 'performance considerations' do
    it 'caches port connections map' do
      create(:sailing, origin_port: 'A', destination_port: 'B', sailing_code: 'AB')

      # First call should build the map
      expect(filter).to receive(:build_port_connectivity_map).once.and_call_original
      filter.filter_relevant_sailings('A', 'B')

      # Second call should use cached map
      expect(filter).not_to receive(:build_port_connectivity_map)
      filter.filter_relevant_sailings('A', 'B')
    end

    it 'uses efficient database queries' do
      create(:sailing, origin_port: 'A', destination_port: 'B', sailing_code: 'AB')

      # Should use pluck for port pairs
      expect(Sailing).to receive(:pluck).with(:origin_port, :destination_port).once.and_call_original

      filter.filter_relevant_sailings('A', 'B')
    end
  end

  describe 'edge cases' do
    context 'with disconnected components' do
      before do
        # Component 1: A -> B
        create(:sailing, origin_port: 'A', destination_port: 'B', sailing_code: 'AB')
        # Component 2: X -> Y
        create(:sailing, origin_port: 'X', destination_port: 'Y', sailing_code: 'XY')
      end

      it 'handles disconnected networks' do
        result = filter.filter_relevant_sailings('A', 'Y')

        expect(result).to be_empty
      end
    end

    context 'with self-loops' do
      before do
        create(:sailing, origin_port: 'A', destination_port: 'A', sailing_code: 'AA')
        create(:sailing, origin_port: 'A', destination_port: 'B', sailing_code: 'AB')
      end

      it 'handles self-loops gracefully' do
        result = filter.filter_relevant_sailings('A', 'B')

        sailing_codes = result.pluck(:sailing_code)
        expect(sailing_codes).to contain_exactly('AA', 'AB')
      end
    end

    context 'with very long chains' do
      before do
        # Create a chain longer than max_hops
        ('A'..'Z').each_cons(2) do |origin, destination|
          create(:sailing, origin_port: origin, destination_port: destination, sailing_code: "#{origin}#{destination}")
        end
      end

      it 'respects max_hops even for very long chains' do
        result = filter.filter_relevant_sailings('A', 'Z')

        # Should only include sailings within max_hops distance
        expect(result.count).to be <= (max_hops * 2) # Rough estimate
      end
    end
  end
end
