require 'rails_helper'

RSpec.describe RouteStrategies::ShippingGraphBuilder do
  subject(:builder) { described_class.new }

  let(:sailing_with_rate) do
    build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', rate: build_stubbed(:rate))
  end
  let(:sailing_without_rate) do
    build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', rate: nil)
  end

  describe '#build_from_sailings' do
    it 'includes only sailings with rates' do
      graph = builder.build_from_sailings([ sailing_with_rate, sailing_without_rate ])
      expect(graph['CNSHA'].map { |r| r[:sailing] }).to include(sailing_with_rate)
      expect(graph['CNSHA'].map { |r| r[:sailing] }).not_to include(sailing_without_rate)
    end

    it 'creates correct graph structure' do
      graph = builder.build_from_sailings([ sailing_with_rate ])
      expect(graph).to have_key('CNSHA')
      expect(graph['CNSHA'].first[:destination]).to eq('NLRTM')
      expect(graph['CNSHA'].first[:duration]).to eq(sailing_with_rate.duration_days)
    end

    it 'returns empty for ports with no sailings' do
      graph = builder.build_from_sailings([])
      expect(graph['CNSHA']).to eq([])
    end
  end
end
