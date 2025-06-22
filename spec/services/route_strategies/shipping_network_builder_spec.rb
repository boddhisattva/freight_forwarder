require 'rails_helper'

RSpec.describe RouteStrategies::ShippingNetworkBuilder do
  # Create a concrete test subclass to test the base class behavior
  class TestRouteBuilder < RouteStrategies::ShippingNetworkBuilder
    private

    def create_route_option(sailing)
      {
        sailing: sailing,
        destination: sailing.destination_port,
        test_data: 'test_value'
      }
    end
  end

  subject(:builder) { TestRouteBuilder.new }

  describe '#build_from_sailings' do
    let(:sailing_with_rate) do
      build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', rate: build_stubbed(:rate))
    end
    let(:sailing_without_rate) do
      build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', rate: nil)
    end

    it 'excludes sailings without rates' do
      result = builder.build_from_sailings([ sailing_with_rate, sailing_without_rate ])
      expect(result['CNSHA'].map { |r| r[:sailing] }).to include(sailing_with_rate)
      expect(result['CNSHA'].map { |r| r[:sailing] }).not_to include(sailing_without_rate)
    end

    it 'creates network structure by origin port' do
      result = builder.build_from_sailings([ sailing_with_rate ])
      expect(result).to have_key('CNSHA')
      expect(result['CNSHA']).to be_an(Array)
    end

    it 'returns empty hash for empty sailings' do
      result = builder.build_from_sailings([])
      expect(result).to be_empty
    end

    it 'groups multiple sailings from same origin port' do
      sailing1 = build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', rate: build_stubbed(:rate))
      sailing2 = build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'ESBCN', rate: build_stubbed(:rate))

      result = builder.build_from_sailings([ sailing1, sailing2 ])
      expect(result['CNSHA'].size).to eq(2)
    end

    it 'calls create_route_option for each sailing with rate' do
      result = builder.build_from_sailings([ sailing_with_rate ])
      route_option = result['CNSHA'].first

      expect(route_option[:sailing]).to eq(sailing_with_rate)
      expect(route_option[:destination]).to eq('NLRTM')
      expect(route_option[:test_data]).to eq('test_value')
    end
  end

  describe 'template method' do
    it 'raises NotImplementedError when create_route_option is not implemented' do
      abstract_builder = RouteStrategies::ShippingNetworkBuilder.new
      sailing = build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', rate: build_stubbed(:rate))

      expect { abstract_builder.build_from_sailings([ sailing ]) }.to raise_error(NotImplementedError, 'Subclasses must implement create_route_option')
    end
  end

  describe 'inheritance structure' do
    it 'is designed to be inherited from' do
      expect(described_class).to be < Object
    end

    it 'has protected template method' do
      expect(described_class.private_instance_methods).to include(:create_route_option)
    end

    it 'can be inherited by concrete classes' do
      expect(TestRouteBuilder.superclass).to eq(RouteStrategies::ShippingNetworkBuilder)
    end
  end
end
