require 'rails_helper'

RSpec.describe RouteStrategies::BellmanFordPathfinder do
  subject(:pathfinder) { described_class.new }

  let(:cost_calculator) { instance_double(CostCalculator) }

  describe '#find_cheapest_path' do
    before do
      allow(cost_calculator).to receive(:valid_connection?).and_return(true)
    end

    context 'with direct routes' do
      it 'finds direct route successfully' do
        shipping_network = build_direct_route_shipping_network

        result = pathfinder.find_cheapest_path(shipping_network, 'CNSHA', 'NLRTM', cost_calculator)

        expect(result.length).to eq(1)
        expect(result.first.sailing_code).to eq('ABCD')
      end
    end

    context 'with multi-hop routes' do
      it 'chooses cheaper multi-hop over expensive direct route' do
        shipping_network = build_multi_hop_vs_direct_shipping_network

        result = pathfinder.find_cheapest_path(shipping_network, 'CNSHA', 'NLRTM', cost_calculator)

        # Multi-hop via Barcelona: €261.96 + €60.93 = €322.89 < €410.11 direct
        expect(result.length).to eq(2)
        expect(result.map(&:sailing_code)).to eq([ 'ERXQ', 'ETRG' ])
      end

      it 'handles complex multi-leg routing with 4+ legs' do
        shipping_network = build_four_leg_route_shipping_network

        result = pathfinder.find_cheapest_path(shipping_network, 'CNSHA', 'USNYC', cost_calculator)

        # 4-leg route: €150 + €80 + €120 + €90 = €440 vs direct €2000
        expect(result.length).to eq(4)
        expect(result.map(&:sailing_code)).to eq([ 'LEG1', 'LEG2', 'LEG3', 'LEG4' ])
      end
    end

    context 'with connection timing constraints' do
      it 'respects invalid connections and finds alternative routes' do
        shipping_network_data = build_multi_hop_vs_direct_shipping_network_with_sailings
        shipping_network = shipping_network_data[:shipping_network]
        shanghai_sailing = shipping_network_data[:shanghai_sailing]
        barcelona_sailing = shipping_network_data[:barcelona_sailing]

        # Break the Barcelona connection
        allow(cost_calculator).to receive(:valid_connection?)
          .with(nil, anything).and_return(true)
        allow(cost_calculator).to receive(:valid_connection?)
          .with(shanghai_sailing, barcelona_sailing).and_return(false)

        result = pathfinder.find_cheapest_path(shipping_network, 'CNSHA', 'NLRTM', cost_calculator)

        # Should fallback to direct route when multi-hop connection invalid
        expect(result.length).to eq(1)
        expect(result.first.sailing_code).to eq('MNOP')
      end
    end

    context 'with edge cases' do
      it 'returns empty array for unreachable destinations' do
        shipping_network = build_direct_route_shipping_network

        result = pathfinder.find_cheapest_path(shipping_network, 'CNSHA', 'UNKNOWN', cost_calculator)

        expect(result).to eq([])
      end

      it 'handles empty shipping_network gracefully' do
        result = pathfinder.find_cheapest_path({}, 'CNSHA', 'NLRTM', cost_calculator)

        expect(result).to eq([])
      end

      it 'handles same origin and destination' do
        shipping_network = { 'CNSHA' => [] }

        result = pathfinder.find_cheapest_path(shipping_network, 'CNSHA', 'CNSHA', cost_calculator)

        expect(result).to eq([])
      end
    end
  end

  private

  def build_direct_route_shipping_network
    sailing = build_stubbed(:sailing,
      origin_port: 'CNSHA',
      destination_port: 'NLRTM',
      sailing_code: 'ABCD'
    )

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

  def build_multi_hop_vs_direct_shipping_network
    shanghai_sailing = build_stubbed(:sailing,
      origin_port: 'CNSHA',
      destination_port: 'ESBCN',
      sailing_code: 'ERXQ'
    )

    barcelona_sailing = build_stubbed(:sailing,
      origin_port: 'ESBCN',
      destination_port: 'NLRTM',
      sailing_code: 'ETRG'
    )

    direct_sailing = build_stubbed(:sailing,
      origin_port: 'CNSHA',
      destination_port: 'NLRTM',
      sailing_code: 'MNOP'
    )

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

  def build_four_leg_route_shipping_network
    leg1_sailing = build_stubbed(:sailing, sailing_code: 'LEG1', origin_port: 'CNSHA', destination_port: 'ESBCN')
    leg2_sailing = build_stubbed(:sailing, sailing_code: 'LEG2', origin_port: 'ESBCN', destination_port: 'NLRTM')
    leg3_sailing = build_stubbed(:sailing, sailing_code: 'LEG3', origin_port: 'NLRTM', destination_port: 'BRSSZ')
    leg4_sailing = build_stubbed(:sailing, sailing_code: 'LEG4', origin_port: 'BRSSZ', destination_port: 'USNYC')
    direct_expensive = build_stubbed(:sailing, sailing_code: 'EXPENSIVE', origin_port: 'CNSHA', destination_port: 'USNYC')

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
          cost_cents: 200000, # €2000.00
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

  def build_multi_hop_vs_direct_shipping_network_with_sailings
    shanghai_sailing = build_stubbed(:sailing,
      origin_port: 'CNSHA',
      destination_port: 'ESBCN',
      sailing_code: 'ERXQ'
    )

    barcelona_sailing = build_stubbed(:sailing,
      origin_port: 'ESBCN',
      destination_port: 'NLRTM',
      sailing_code: 'ETRG'
    )

    direct_sailing = build_stubbed(:sailing,
      origin_port: 'CNSHA',
      destination_port: 'NLRTM',
      sailing_code: 'MNOP'
    )

    shipping_network = {
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

    {
      shipping_network: shipping_network,
      shanghai_sailing: shanghai_sailing,
      barcelona_sailing: barcelona_sailing,
      direct_sailing: direct_sailing
    }
  end

  def sailing_with_code(code)
    double('Sailing', sailing_code: code)
  end
end
