require 'rails_helper'

RSpec.describe RouteStrategies::ShippingNetworkDurationBuilder do
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

    it 'creates correct route option structure' do
      graph = builder.build_from_sailings([ sailing_with_rate ])
      route_option = graph['CNSHA'].first

      expect(route_option[:sailing]).to eq(sailing_with_rate)
      expect(route_option[:destination]).to eq('NLRTM')
      expect(route_option[:departure_date]).to eq(sailing_with_rate.departure_date)
      expect(route_option[:arrival_date]).to eq(sailing_with_rate.arrival_date)
      expect(route_option[:duration]).to eq(sailing_with_rate.duration_days)
    end
  end

  describe 'inheritance' do
    it 'inherits from ShippingNetworkBuilder' do
      expect(described_class.superclass).to eq(RouteStrategies::ShippingNetworkBuilder)
    end

    it 'implements the template method' do
      sailing = build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM')
      rate = build_stubbed(:rate)
      allow(sailing).to receive(:rate).and_return(rate)

      result = builder.build_from_sailings([ sailing ])

      expect(result['CNSHA'].first).to include(:duration)
      expect(result['CNSHA'].first[:duration]).to eq(sailing.duration_days)
    end
  end
end
