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

    describe 'core filtering behavior' do
      it 'excludes sailings without rates' do
        result = builder.build_from_sailings([ sailing_with_rate, sailing_without_rate ])

        expect(result['CNSHA'].map { |r| r[:sailing] }).to include(sailing_with_rate)
        expect(result['CNSHA'].map { |r| r[:sailing] }).not_to include(sailing_without_rate)
      end

      it 'handles nil rate gracefully' do
        sailing_with_nil_rate = build_stubbed(:sailing, origin_port: 'CNSHA', rate: nil)

        expect { builder.build_from_sailings([ sailing_with_nil_rate ]) }.not_to raise_error

        result = builder.build_from_sailings([ sailing_with_nil_rate ])
        expect(result['CNSHA']).to be_empty
      end
    end

    describe 'network structure creation' do
      it 'creates network structure by origin port' do
        result = builder.build_from_sailings([ sailing_with_rate ])

        expect(result).to have_key('CNSHA')
        expect(result['CNSHA']).to be_an(Array)
      end

      it 'groups multiple sailings from same origin port' do
        sailing1 = build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', rate: build_stubbed(:rate))
        sailing2 = build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'ESBCN', rate: build_stubbed(:rate))

        result = builder.build_from_sailings([ sailing1, sailing2 ])

        expect(result['CNSHA'].size).to eq(2)
        destinations = result['CNSHA'].map { |r| r[:destination] }
        expect(destinations).to contain_exactly('NLRTM', 'ESBCN')
      end

      it 'creates separate entries for different origin ports' do
        cnsha_sailing = build_stubbed(:sailing, origin_port: 'CNSHA', rate: build_stubbed(:rate))
        esbcn_sailing = build_stubbed(:sailing, origin_port: 'ESBCN', rate: build_stubbed(:rate))

        result = builder.build_from_sailings([ cnsha_sailing, esbcn_sailing ])

        expect(result.keys).to contain_exactly('CNSHA', 'ESBCN')
        expect(result['CNSHA'].size).to eq(1)
        expect(result['ESBCN'].size).to eq(1)
      end
    end

    describe 'empty input handling' do
      it 'returns empty hash for empty sailings' do
        result = builder.build_from_sailings([])
        expect(result).to be_empty
      end

      it 'returns empty arrays for ports with no valid sailings' do
        result = builder.build_from_sailings([ sailing_without_rate ])
        expect(result['CNSHA']).to eq([])
      end
    end

    describe 'template method integration' do
      it 'calls create_route_option for each sailing with rate' do
        result = builder.build_from_sailings([ sailing_with_rate ])
        route_option = result['CNSHA'].first

        expect(route_option[:sailing]).to eq(sailing_with_rate)
        expect(route_option[:destination]).to eq('NLRTM')
        expect(route_option[:test_data]).to eq('test_value')
      end

      it 'preserves all data from create_route_option' do
        multi_data_builder = Class.new(RouteStrategies::ShippingNetworkBuilder) do
          private

          def create_route_option(sailing)
            {
              sailing: sailing,
              destination: sailing.destination_port,
              departure: sailing.departure_date,
              arrival: sailing.arrival_date,
              code: sailing.sailing_code
            }
          end
        end

        result = multi_data_builder.new.build_from_sailings([ sailing_with_rate ])
        route_option = result['CNSHA'].first

        expect(route_option).to include(
          sailing: sailing_with_rate,
          destination: sailing_with_rate.destination_port,
          departure: sailing_with_rate.departure_date,
          arrival: sailing_with_rate.arrival_date,
          code: sailing_with_rate.sailing_code
        )
      end
    end

    describe 'scalability behavior' do
      it 'handles large number of sailings efficiently' do
        large_sailing_set = 100.times.map do |i|
          build_stubbed(:sailing,
            origin_port: "PORT#{i % 10}",
            destination_port: "DEST#{i}",
            sailing_code: "CODE#{i}",
            rate: build_stubbed(:rate)
          )
        end

        expect { builder.build_from_sailings(large_sailing_set) }.not_to raise_error

        result = builder.build_from_sailings(large_sailing_set)
        expect(result.keys.size).to eq(10) # 10 different origin ports
        expect(result.values.flatten.size).to eq(100) # All sailings included
      end
    end
  end

  describe 'template method pattern' do
    it 'raises NotImplementedError when create_route_option is not implemented' do
      abstract_builder = RouteStrategies::ShippingNetworkBuilder.new
      sailing = build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', rate: build_stubbed(:rate))

      expect { abstract_builder.build_from_sailings([ sailing ]) }
        .to raise_error(NotImplementedError, 'Subclasses must implement create_route_option')
    end

    it 'allows subclasses to define custom route option structure' do
      sailing = build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', rate: build_stubbed(:rate))

      custom_builder = Class.new(RouteStrategies::ShippingNetworkBuilder) do
        private

        def create_route_option(sailing)
          {
            custom_field: 'custom_value',
            port_pair: "#{sailing.origin_port}-#{sailing.destination_port}"
          }
        end
      end

      result = custom_builder.new.build_from_sailings([ sailing ])
      route_option = result['CNSHA'].first

      expect(route_option[:custom_field]).to eq('custom_value')
      expect(route_option[:port_pair]).to eq('CNSHA-NLRTM')
    end
  end

  describe 'inheritance structure' do
    it 'is designed to be inherited from' do
      expect(described_class).to be < Object
    end

    it 'has private template method' do
      expect(described_class.private_instance_methods).to include(:create_route_option)
    end

    it 'can be inherited by concrete classes' do
      expect(TestRouteBuilder.superclass).to eq(RouteStrategies::ShippingNetworkBuilder)
    end

    it 'maintains consistent interface across subclasses' do
      expect(TestRouteBuilder.instance_methods).to include(:build_from_sailings)
      expect(TestRouteBuilder.new).to respond_to(:build_from_sailings)
    end
  end
end
